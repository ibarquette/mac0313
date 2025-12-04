-- Valida se o usuário pode enviar mensagem no chat
-- Verifica participação no chat e status do agendamento
CREATE OR REPLACE FUNCTION trigger_validar_mensagem()
RETURNS TRIGGER AS $$
DECLARE
    v_status status_agendamento;
BEGIN
    -- Verifica se o remetente faz parte do chat
    IF NOT EXISTS (
        SELECT 1
        FROM chat_aluno ca
        WHERE ca.id_agendamento = NEW.id_agendamento
          AND ca.id_chat = NEW.id_chat
          AND ca.nusp = NEW.nusp_remetente
    ) THEN
        RAISE EXCEPTION 'Usuário não faz parte deste chat e não pode enviar mensagens';
    END IF;

    -- Busca o status do agendamento
    SELECT status INTO v_status
    FROM agendamento
    WHERE id = NEW.id_agendamento;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Agendamento % não encontrado', NEW.id_agendamento;
    END IF;

    -- Mensagens só podem ser enviadas em agendamentos confirmados
    IF v_status NOT IN ('confirmado') THEN
        RAISE EXCEPTION 'Mensagens só podem ser enviadas em agendamentos confirmados. Status atual: %', v_status;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_mensagem
    BEFORE INSERT ON mensagem
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validar_mensagem();

-------------------------------------------------------------------------------
-- Impede edição de mensagens que já foram marcadas como deletadas
CREATE OR REPLACE FUNCTION trigger_impedir_editar_mensagem_deletada()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.foi_deletada = TRUE THEN
        RAISE EXCEPTION 'Não é permitido editar mensagem deletada';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_impedir_editar_mensagem_deletada
    BEFORE UPDATE ON mensagem
    FOR EACH ROW
    EXECUTE FUNCTION trigger_impedir_editar_mensagem_deletada();
