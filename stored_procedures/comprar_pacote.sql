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
