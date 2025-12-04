-- Adiciona uma lista de alunos extras a uma aula concluída (para aulas em grupo)
-- Valida se a aula existe, está finalizada e se os alunos são válidos
CREATE OR REPLACE FUNCTION adicionar_aluno_aula(
    p_id_agendamento INTEGER,
    p_nusps_alunos VARCHAR(20)[]
) RETURNS VOID AS $$
DECLARE
    v_status status_agendamento;
    v_nusp_tutor VARCHAR(20);
    v_nusp_solicitante VARCHAR(20);
    v_nusp_aluno VARCHAR(20);
    v_contador INTEGER := 0;
BEGIN
    -- Busca dados do agendamento
    SELECT status, nusp_tutor, nusp_solicitante
    INTO v_status, v_nusp_tutor, v_nusp_solicitante
    FROM agendamento
    WHERE id = p_id_agendamento;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;

    -- Só pode adicionar alunos em aulas já finalizadas
    IF v_status != 'concluido' THEN
        RAISE EXCEPTION 'Só é possível adicionar alunos a aulas já finalizadas';
    END IF;

    -- Processa cada aluno da lista
    FOREACH v_nusp_aluno IN ARRAY p_nusps_alunos LOOP
        -- Verifica se o aluno existe
        IF NOT EXISTS (SELECT 1 FROM aluno WHERE nusp = v_nusp_aluno) THEN
            RAISE NOTICE 'Aluno % não encontrado - pulando', v_nusp_aluno;
            CONTINUE;
        END IF;

        -- Não permite adicionar o tutor como aluno
        IF v_nusp_aluno = v_nusp_tutor THEN
            RAISE NOTICE 'Não é possível adicionar o tutor como aluno - pulando %', v_nusp_aluno;
            CONTINUE;
        END IF;

        -- Verifica se já não está na aula (incluindo o solicitante original)
        IF EXISTS (
            SELECT 1 FROM aluno_aula
            WHERE id_agendamento = p_id_agendamento
            AND nusp_aluno = v_nusp_aluno
        ) THEN
            RAISE NOTICE 'Aluno % já está registrado nesta aula - pulando', v_nusp_aluno;
            CONTINUE;
        END IF;

        -- Adiciona o aluno à aula
        INSERT INTO aluno_aula (id_agendamento, nusp_aluno)
        VALUES (p_id_agendamento, v_nusp_aluno);

        v_contador := v_contador + 1;
    END LOOP;

    RAISE NOTICE '% aluno(s) adicionado(s) à aula %', v_contador, p_id_agendamento;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------
-- Cancela um agendamento (pendente ou confirmado)
-- Se já foi confirmado, reverte a transação de créditos
CREATE OR REPLACE FUNCTION cancelar_agendamento(
    p_id_agendamento INTEGER,
    p_nusp_cancelador VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_preco NUMERIC(10,2);
    v_nusp_solicitante VARCHAR(20);
    v_nusp_tutor VARCHAR(20);
    v_status status_agendamento;
BEGIN
    SELECT status, preco, nusp_solicitante, nusp_tutor
    INTO v_status, v_preco, v_nusp_solicitante, v_nusp_tutor
    FROM agendamento
    WHERE id = p_id_agendamento;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;

    IF v_status NOT IN ('pendente', 'confirmado') THEN
        RAISE EXCEPTION 'Não pode cancelar';
    END IF;

    -- Se já estava confirmado, precisa reverter a transação
    IF v_status = 'confirmado' THEN
        -- Devolve créditos pro aluno
        UPDATE aluno
        SET qtd_creditos = qtd_creditos + v_preco
        WHERE nusp = v_nusp_solicitante;

        -- Tira créditos do tutor (mesmo valor)
        UPDATE aluno
        SET qtd_creditos = qtd_creditos - v_preco
        WHERE nusp = v_nusp_tutor;
    END IF;

    UPDATE agendamento
    SET status = 'cancelado'
    WHERE id = p_id_agendamento;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------
-- Compra um pacote de créditos aplicando desconto baseado na média de avaliações do aluno
-- Quanto melhor avaliado o aluno, maior o desconto
CREATE OR REPLACE FUNCTION comprar_pacote(
    p_nusp VARCHAR(20),
    p_qtd_credito INTEGER
) RETURNS VOID AS $$
DECLARE
    v_preco_base NUMERIC(10,2);
    v_preco_final NUMERIC(10,2);
    v_media_avaliacao NUMERIC(3,2);
    v_desconto_percentual NUMERIC(5,2) := 0;
BEGIN
    -- Busca preço do pacote
    SELECT preco INTO v_preco_base
    FROM pacote WHERE qtd_credito = p_qtd_credito;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pacote não existe';
    END IF;

    -- Calcula média de avaliações que o aluno recebeu
    SELECT COALESCE(AVG(nota), 0) INTO v_media_avaliacao
    FROM avaliacao
    WHERE nusp_avaliado = p_nusp;

    -- Define desconto com base na média (melhor comportamento = maior desconto)
    IF v_media_avaliacao >= 4.6 THEN
        v_desconto_percentual := 20;
    ELSIF v_media_avaliacao >= 4.1 THEN
        v_desconto_percentual := 15;
    ELSIF v_media_avaliacao >= 3.1 THEN
        v_desconto_percentual := 10;
    ELSIF v_media_avaliacao >= 2.1 THEN
        v_desconto_percentual := 5;
    END IF;

    v_preco_final := v_preco_base * (1 - v_desconto_percentual / 100.0);

    -- Registra compra com preço final (já com desconto aplicado)
    INSERT INTO aluno_pacote (qtd_credito, nusp_comprador, preco)
    VALUES (p_qtd_credito, p_nusp, v_preco_final);

    -- Adiciona créditos na conta do aluno
    UPDATE aluno
    SET qtd_creditos = qtd_creditos + p_qtd_credito
    WHERE nusp = p_nusp;

END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------
-- Confirma um agendamento pendente e realiza a transação de créditos
-- Aluno e tutor trabalham com o mesmo valor (desconto já foi aplicado na compra do pacote)
CREATE OR REPLACE FUNCTION confirmar_agendamento(
    p_id_agendamento INTEGER,
    p_nusp_tutor VARCHAR(20)
) RETURNS VOID AS $$
DECLARE
    v_creditos NUMERIC(10,2);
    v_nusp_solicitante VARCHAR(20);
BEGIN
    -- Busca dados do agendamento (só se for pendente)
    SELECT preco, nusp_solicitante
    INTO v_creditos, v_nusp_solicitante
    FROM agendamento
    WHERE id = p_id_agendamento AND nusp_tutor = p_nusp_tutor AND status = 'pendente';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado ou já processado';
    END IF;

    -- Debita do aluno
    UPDATE aluno
    SET qtd_creditos = qtd_creditos - v_creditos
    WHERE nusp = v_nusp_solicitante;

    -- Credita ao tutor (mesmo valor)
    UPDATE aluno
    SET qtd_creditos = qtd_creditos + v_creditos
    WHERE nusp = p_nusp_tutor;

    UPDATE agendamento
    SET status = 'confirmado'
    WHERE id = p_id_agendamento;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------
-- Cria um novo agendamento de tutoria em status 'pendente'
-- Valida créditos do aluno e disponibilidade do tutor
CREATE OR REPLACE FUNCTION criar_agendamento(
    p_nusp_solicitante VARCHAR(20),
    p_nusp_tutor VARCHAR(20),
    p_data DATE,
    p_h_inicio TIME,
    p_h_fim TIME,
    p_modo_atendimento modo_atendimento,
    p_localizacao VARCHAR(200),
    p_assuntos TEXT[]
) RETURNS INTEGER AS $$
DECLARE
    v_id_agendamento INTEGER;
    v_creditos_aluno NUMERIC(10,2);
    v_creditos_necessarios INTEGER;
    v_duracao_minutos INTEGER;
    v_assunto TEXT;
BEGIN
    -- Calcula duração em minutos
    v_duracao_minutos := EXTRACT(EPOCH FROM (p_h_fim - p_h_inicio)) / 60;

    IF v_duracao_minutos < 30 THEN
        RAISE EXCEPTION 'Duração mínima: 30 minutos';
    END IF;

    -- 1 crédito = 30 minutos (sempre arredonda pra cima)
    v_creditos_necessarios := CEIL(v_duracao_minutos / 30.0);

    SELECT qtd_creditos INTO v_creditos_aluno
    FROM aluno WHERE nusp = p_nusp_solicitante;

    IF v_creditos_aluno < v_creditos_necessarios THEN
        RAISE EXCEPTION 'Créditos insuficientes. Necessário: %, Disponível: %',
            v_creditos_necessarios, v_creditos_aluno;
    END IF;

    -- Verifica se o tutor tem disponibilidade cadastrada que cubra todo o período
    IF NOT EXISTS (
        SELECT 1 FROM disponibilidade_tutor
        WHERE nusp_tutor = p_nusp_tutor
        AND data = p_data
        AND h_inicio <= p_h_inicio
        AND h_fim >= p_h_fim
    ) THEN
        RAISE EXCEPTION 'Tutor não disponível';
    END IF;

    -- Cria agendamento (créditos NÃO são debitados aqui, só na confirmação)
    INSERT INTO agendamento (
        nusp_solicitante, nusp_tutor, data, h_inicio, h_fim,
        modo_atendimento, localizacao, preco, status
    ) VALUES (
        p_nusp_solicitante, p_nusp_tutor, p_data, p_h_inicio, p_h_fim,
        p_modo_atendimento, p_localizacao, v_creditos_necessarios, 'pendente'
    ) RETURNING id INTO v_id_agendamento;

    FOREACH v_assunto IN ARRAY p_assuntos LOOP
        INSERT INTO assunto_agendamento (id_agendamento, assunto)
        VALUES (v_id_agendamento, v_assunto);
    END LOOP;

    RETURN v_id_agendamento;
END;
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------------------------
-- Finaliza um agendamento confirmado, transformando-o em aula concluída
-- Adiciona automaticamente o solicitante e o tutor na lista de participantes
CREATE OR REPLACE FUNCTION finalizar_aula(
    p_id_agendamento INTEGER
) RETURNS VOID AS $$
DECLARE
    v_status status_agendamento;
    v_h_inicio TIME;
    v_h_fim TIME;
    v_data DATE;
    v_nusp_solicitante VARCHAR(20);
    v_nusp_tutor VARCHAR(20);
BEGIN
    -- Busca dados do agendamento
    SELECT status, h_inicio, h_fim, data, nusp_solicitante, nusp_tutor
    INTO v_status, v_h_inicio, v_h_fim, v_data, v_nusp_solicitante, v_nusp_tutor
    FROM agendamento
    WHERE id = p_id_agendamento;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento não encontrado';
    END IF;

    -- Só pode finalizar agendamentos confirmados
    IF v_status != 'confirmado' THEN
        RAISE EXCEPTION 'Só é possível finalizar agendamentos confirmados. Status atual: %', v_status;
    END IF;

    -- Muda status para concluído
    UPDATE agendamento
    SET status = 'concluido'
    WHERE id = p_id_agendamento;

    -- Cria registro da aula
    INSERT INTO aula (id_agendamento, h_inicio, h_fim, data)
    VALUES (p_id_agendamento, v_h_inicio, v_h_fim, v_data);

    -- Adiciona o aluno solicitante na lista de participantes
    INSERT INTO aluno_aula (id_agendamento, nusp_aluno)
    VALUES (p_id_agendamento, v_nusp_solicitante);

    -- Adiciona o tutor também na lista de participantes
    INSERT INTO aluno_aula (id_agendamento, nusp_aluno)
    VALUES (p_id_agendamento, v_nusp_tutor);

    RAISE NOTICE 'Aula finalizada com sucesso! ID: %', p_id_agendamento;
END;
$$ LANGUAGE plpgsql;
