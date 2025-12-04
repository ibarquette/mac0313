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
