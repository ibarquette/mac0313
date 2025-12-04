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
