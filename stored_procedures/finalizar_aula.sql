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
