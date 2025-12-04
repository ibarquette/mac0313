--Listar todos os tutores com seus nomes e disciplinas

SELECT t.nusp AS tutor_nusp,
       al.pnome AS tutor_primeiro_nome,
       d.nome AS disciplina_nome
FROM tutor t
JOIN aluno al ON al.nusp = t.nusp
JOIN tutor_disciplina td ON td.nusp_tutor = t.nusp
JOIN disciplina d ON d.codigo = td.cod_disciplina
ORDER BY al.pnome, d.nome;

-----------------------------------------------------------------------------------
--Próximos 10 agendamentos futuros (a partir do dia 22/11/2025)
SELECT ag.id AS agendamento_id,
       al.nusp AS aluno_nusp,
       al.pnome AS aluno_primeiro_nome,
       t.nusp AS tutor_nusp,
       al_tutor.pnome AS tutor_primeiro_nome,
       ag.data,
       ag.h_inicio
FROM agendamento ag
JOIN aluno al ON al.nusp = ag.nusp_solicitante
JOIN tutor t ON t.nusp = ag.nusp_tutor
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
WHERE (ag.data > '2025-11-22')
   OR (ag.data = '2025-11-22' AND ag.h_inicio > '10:00:00')
ORDER BY ag.data, ag.h_inicio
LIMIT 10;

-----------------------------------------------------------------------------------
--Contar alunos por curso

SELECT al.curso AS curso_codigo,
       c.nome AS curso_nome,
       COUNT(*) AS num_alunos
FROM aluno al
LEFT JOIN curso c ON c.codigo = al.curso
GROUP BY al.curso, c.nome
ORDER BY num_alunos DESC;

-----------------------------------------------------------------------------------
--Últimas 5 mensagens de um agendamento

SELECT m.id_mensagem AS mensagem_id,
       m.nusp_remetente AS autor_nusp,
       m.conteudo,
       m.horario AS timestamp
FROM mensagem m
JOIN chat c ON c.id_chat = m.id_chat
WHERE c.id_agendamento = 8
ORDER BY m.horario DESC
LIMIT 5;

-----------------------------------------------------------------------------------
--Top 5 institutos por número de alunos

SELECT i.nome AS instituto,
       COUNT(*) AS num_alunos
FROM aluno al
JOIN curso c ON c.codigo = al.curso
JOIN instituto i ON i.nome = c.id_instituto
GROUP BY i.nome
ORDER BY num_alunos DESC
LIMIT 5;

-----------------------------------------------------------------------------------
--Top 10 tutores com maior número de alunos diferentes atendidos

SELECT t.nusp AS tutor_nusp,
       al_tutor.pnome AS tutor_primeiro_nome,
       COUNT(DISTINCT ag.nusp_solicitante) AS alunos_unicos
FROM tutor t
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
LEFT JOIN agendamento ag ON ag.nusp_tutor = t.nusp
GROUP BY t.nusp, al_tutor.pnome
ORDER BY alunos_unicos DESC
LIMIT 10;

-----------------------------------------------------------------------------------
--Tutores disponíveis em um intervalo

SELECT DISTINCT t.nusp,
       al.pnome AS tutor_primeiro_nome
FROM disponibilidade_tutor d
JOIN tutor t ON t.nusp = d.nusp_tutor
JOIN aluno al ON al.nusp = t.nusp
WHERE d.data = '2025-11-29'
  AND d.h_inicio <= '20:00:00'
  AND d.h_fim    >= '21:00:00';

-----------------------------------------------------------------------------------
--Número de mensagens por agendamento, ate 10

SELECT c.id_agendamento,
       COUNT(m.id_mensagem) AS num_mensagens
FROM chat c
JOIN mensagem m ON m.id_chat = c.id_chat
GROUP BY c.id_agendamento
ORDER BY num_mensagens DESC
LIMIT 10;

-----------------------------------------------------------------------------------
--Agendamentos cancelados por alunos em um periodo

SELECT ag.nusp_solicitante AS aluno_nusp,
       al.pnome AS aluno_primeiro_nome,
       COUNT(*) AS cancelados
FROM agendamento ag
JOIN aluno al ON al.nusp = ag.nusp_solicitante
WHERE ag.status = 'cancelado'
  AND ag.data >= '2024-10-25'
  AND ag.data <= '2025-11-25'
GROUP BY ag.nusp_solicitante, al.pnome
ORDER BY cancelados DESC
LIMIT 20;

-----------------------------------------------------------------------------------
--Quantidade total de créditos comprados por curso

SELECT al.curso,
       c.nome AS curso_nome,
       SUM(p.qtd_credito) AS total_creditos
FROM aluno_pacote ap
JOIN pacote p ON p.qtd_credito = ap.qtd_credito
JOIN aluno al ON al.nusp = ap.nusp_comprador
JOIN curso c ON c.codigo = al.curso
GROUP BY al.curso, c.nome
ORDER BY total_creditos DESC;

-----------------------------------------------------------------------------------
--Alunos que cancelaram algum agendamento

SELECT al.nusp,
       al.pnome AS aluno_primeiro_nome,
       COUNT(*) AS total_cancelamentos
FROM agendamento ag
JOIN aluno al ON al.nusp = ag.nusp_solicitante
WHERE ag.status = 'cancelado'
GROUP BY al.nusp, al.pnome
HAVING COUNT(*) > 0
ORDER BY total_cancelamentos DESC;

-----------------------------------------------------------------------------------
--Número de agendamentos por tutor

SELECT t.nusp AS tutor_nusp,
       al_tutor.pnome AS tutor_primeiro_nome,
       COUNT(ag.id) AS total_agendamentos
FROM tutor t
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
LEFT JOIN agendamento ag ON ag.nusp_tutor = t.nusp
GROUP BY t.nusp, al_tutor.pnome
ORDER BY total_agendamentos DESC;

-----------------------------------------------------------------------------------
--Agendamentos sem mensagens

SELECT ag.id AS agendamento_id,
       al.pnome AS aluno_primeiro_nome,
       al_tutor.pnome AS tutor_primeiro_nome
FROM agendamento ag
JOIN aluno al ON al.nusp = ag.nusp_solicitante
JOIN tutor t ON t.nusp = ag.nusp_tutor
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
WHERE NOT EXISTS (
    SELECT 1
    FROM chat c
    WHERE c.id_agendamento = ag.id
);

-----------------------------------------------------------------------------------
--Tutores avaliados por todos os alunos atendidos

SELECT t.nusp,
       al_tutor.pnome AS tutor_primeiro_nome
FROM tutor t
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT DISTINCT ag.nusp_solicitante AS aluno_nusp
        FROM agendamento ag
        WHERE ag.nusp_tutor = t.nusp
    ) AS alunos
    WHERE NOT EXISTS (
        SELECT 1
        FROM avaliacao av
        WHERE av.nusp_avaliador = alunos.aluno_nusp
          AND av.nusp_avaliado = t.nusp
    )
);


-----------------------------------------------------------------------------------
--Ranking de tutores como desempenho superior ao promedio global

SELECT t.nusp,
       al_tutor.pnome AS tutor_primeiro_nome,
       ROUND(AVG(av.nota), 2) AS media_tutor,
       COUNT(av.nota) AS qtd
FROM tutor t
JOIN aluno al_tutor ON al_tutor.nusp = t.nusp
JOIN avaliacao av ON av.nusp_avaliado = t.nusp
GROUP BY t.nusp, al_tutor.pnome
HAVING AVG(av.nota) >
      (SELECT AVG(av2.nota) FROM avaliacao av2)
   AND COUNT(av.nota) >= 2
ORDER BY media_tutor DESC;
