-- 1. COMPRAR PACOTE DE CRÉDITOS
SELECT comprar_pacote(
    '9768',  -- nusp
    10       -- qtd_credito
);

-----------------------------------------------------------------------------------
-- 2. CRIAR AGENDAMENTO 
SELECT criar_agendamento(
    '9768',                              -- nusp_solicitante
    '1070',                              -- nusp_tutor
    '2025-12-05',                        -- data
    '14:00:00',                          -- h_inicio
    '15:30:00',                          -- h_fim
    'online',                            -- modo_atendimento
    NULL,                                -- localizacao
    ARRAY['Biologia Molecular', 'DNA']  -- assuntos
);

-----------------------------------------------------------------------------------
-- 3. CONFIRMAR AGENDAMENTO
SELECT confirmar_agendamento(
    1,       -- id_agendamento
    '1070'   -- nusp_tutor
);

-----------------------------------------------------------------------------------
-- 4. ENVIAR MENSAGEM
INSERT INTO mensagem (id_chat, id_agendamento, id_mensagem, nusp_remetente, conteudo, versao)
VALUES (
    11,                                                      -- id_chat
    8,                                                       -- id_agendamento
    1,                                                       -- id_mensagem
    '1169',                                                  -- nusp_remetente
    'Ola',                                                   -- conteudo
    1                                                        -- versao
);

-----------------------------------------------------------------------------------
-- 5. FINALIZAR AULA
SELECT finalizar_aula(1);  -- id_agendamento

-----------------------------------------------------------------------------------
-- 6. ADICIONAR ALUNO A AULA EM GRUPO
INSERT INTO aluno_aula (id_agendamento, nusp_aluno)
VALUES (
    1,       -- id_agendamento
    '1602'   -- nusp_aluno
);

-----------------------------------------------------------------------------------
-- 7. CRIAR AVALIAÇÃO
INSERT INTO avaliacao (id_agendamento, nusp_avaliador, nusp_avaliado, nota, comentario)
VALUES (
    1,                                                     -- id_agendamento
    '9768',                                                -- nusp_avaliador
    '1070',                                                -- nusp_avaliado
    4.8,                                                   -- nota
    'Excelente explicação sobre DNA, muito didática!'     -- comentario
);

-----------------------------------------------------------------------------------
-- 8. CANCELAR AGENDAMENTO
SELECT cancelar_agendamento(
    12,       -- id_agendamento
    '1490'   -- nusp_cancelador
);

-----------------------------------------------------------------------------------
-- 9. REGISTRAR DISPONIBILIDADE
INSERT INTO disponibilidade_tutor (nusp_tutor, data, h_inicio, h_fim)
VALUES
    ('1070', '2025-12-06', '14:00:00', '18:00:00'),
    ('1070', '2025-12-07', '10:00:00', '16:00:00'),
    ('1183', '2025-12-06', '09:00:00', '12:00:00');

-----------------------------------------------------------------------------------
-- 10. REGISTRAR TUTOR EM DISCIPLINA
INSERT INTO tutor_disciplina (nusp_tutor, cod_disciplina)
VALUES (
    '1070',     -- nusp_tutor
    'D008ZMR'   -- cod_disciplina
);

-----------------------------------------------------------------------------------
-- 11. ATUALIZAR DADOS DO ALUNO
UPDATE aluno
SET
    pnome = 'Juliana',                   -- pnome
    mnome = 'Silva',                     -- mnome
    fnome = 'Alves',                     -- fnome
    email = 'juliana.s.alves@usp.br'     -- email
WHERE nusp = '1070';

-----------------------------------------------------------------------------------
-- 12. CRIAR DENÚNCIA
INSERT INTO denuncia (nusp_denunciador, nusp_alvo, motivo)
VALUES (
    '9768',                                               -- nusp_denunciador
    '1616',                                               -- nusp_alvo
    'Não compareceu à aula confirmada sem aviso prévio'  -- motivo
);

-----------------------------------------------------------------------------------
-- 13. ATUALIZAR STATUS DE DENÚNCIA
UPDATE denuncia
SET status = 'em_analise'  -- status
WHERE nusp_denunciador = '9768'
  AND nusp_alvo = '1616'
  AND criada_em = (
    SELECT MAX(criada_em)
    FROM denuncia
    WHERE nusp_denunciador = '9768' AND nusp_alvo = '1616'
  );

-----------------------------------------------------------------------------------
-- 14. EDITAR MENSAGEM
INSERT INTO mensagem (id_chat, id_agendamento, id_mensagem, nusp_remetente, conteudo, versao)
VALUES (
    11,                                                      -- id_chat
    8,                                                       -- id_agendamento
    1,                                                       -- id_mensagem
    '1169',                                                  -- nusp_remetente
    'Ola, tudo bem?',                                        -- conteudo
    2                                                        -- versao
);

-----------------------------------------------------------------------------------
-- 15. REMOVER DISPONIBILIDADES ANTIGAS
DELETE FROM disponibilidade_tutor
WHERE data < CURRENT_DATE
  AND NOT EXISTS (
    SELECT 1 FROM agendamento a
    WHERE a.nusp_tutor = disponibilidade_tutor.nusp_tutor
      AND a.data = disponibilidade_tutor.data
      AND a.status IN ('pendente', 'confirmado')
  );
