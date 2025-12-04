-- Valida se a localização está correta de acordo com o modo de atendimento
-- Presencial: localização obrigatória | Online: localização deve ser NULL
CREATE OR REPLACE FUNCTION trigger_validar_localizacao()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.modo_atendimento = 'presencial' THEN
        IF NEW.localizacao IS NULL OR TRIM(NEW.localizacao) = '' THEN
            RAISE EXCEPTION 'Localização é obrigatória para modo presencial';
        END IF;

    ELSIF NEW.modo_atendimento = 'online' THEN
        IF NEW.localizacao IS NOT NULL THEN
            RAISE EXCEPTION 'Localização deve ser NULL para modo online';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_localizacao
    BEFORE INSERT OR UPDATE ON agendamento
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validar_localizacao();

-------------------------------------------------------------------------------
-- Impede que um tutor tenha agendamentos com horários sobrepostos
-- Verifica apenas agendamentos pendentes ou confirmados (cancelados/concluídos não bloqueiam)
CREATE OR REPLACE FUNCTION trigger_impedir_conflito_horario()
RETURNS TRIGGER AS $$
BEGIN
    -- Verifica se existe sobreposição com agendamentos ativos do tutor
    IF EXISTS (
        SELECT 1
        FROM agendamento ag
        WHERE ag.nusp_tutor = NEW.nusp_tutor
          AND ag.data = NEW.data
          AND ag.status IN ('pendente', 'confirmado')
          AND ag.id != COALESCE(NEW.id, -1)
          AND (
              -- Novo agendamento começa durante outro existente
              (NEW.h_inicio >= ag.h_inicio AND NEW.h_inicio < ag.h_fim)
              OR
              -- Novo agendamento termina durante outro existente
              (NEW.h_fim > ag.h_inicio AND NEW.h_fim <= ag.h_fim)
              OR
              -- Novo agendamento engloba outro existente
              (NEW.h_inicio <= ag.h_inicio AND NEW.h_fim >= ag.h_fim)
          )
    ) THEN
        RAISE EXCEPTION 'Tutor já possui agendamento neste horário';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_impedir_conflito_horario
    BEFORE INSERT OR UPDATE ON agendamento
    FOR EACH ROW
    EXECUTE FUNCTION trigger_impedir_conflito_horario();

-------------------------------------------------------------------------------
-- Controla as transições de status válidas do agendamento
-- Impede mudanças inválidas e garante que estados terminais não sejam alterados
CREATE OR REPLACE FUNCTION trigger_validar_transicao_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o status não mudou, permite
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    -- Define transições válidas para cada status
    IF OLD.status = 'pendente' THEN
        IF NEW.status NOT IN ('confirmado', 'cancelado') THEN
            RAISE EXCEPTION 'Status pendente só pode mudar para confirmado ou cancelado';
        END IF;

    ELSIF OLD.status = 'confirmado' THEN
        IF NEW.status NOT IN ('concluido', 'cancelado') THEN
            RAISE EXCEPTION 'Status confirmado só pode mudar para concluído ou cancelado';
        END IF;

    ELSIF OLD.status = 'concluido' THEN
        RAISE EXCEPTION 'Status concluído é final, não pode ser alterado';

    ELSIF OLD.status = 'cancelado' THEN
        RAISE EXCEPTION 'Status cancelado é final, não pode ser alterado';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validar_transicao_status
    BEFORE UPDATE ON agendamento
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validar_transicao_status();

-------------------------------------------------------------------------------
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
