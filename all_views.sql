CREATE VIEW v_ranking_tutores AS
SELECT 
    t.nusp,
    a.pnome || ' ' || COALESCE(a.mnome || ' ', '') || a.fnome as nome_completo,
    COUNT(DISTINCT CASE WHEN ag.status = 'concluido' THEN ag.id END) as aulas_concluidas,
    COUNT(DISTINCT CASE WHEN ag.status = 'confirmado' THEN ag.id END) as aulas_confirmadas,
    COUNT(DISTINCT CASE WHEN ag.status = 'pendente' THEN ag.id END) as aulas_pendentes,
    ROUND(AVG(av.nota), 2) as avaliacao_media,
    COUNT(DISTINCT av.nusp_avaliador) as qtd_avaliacoes,
    ROUND(SUM(CASE WHEN ag.status IN ('confirmado', 'concluido') THEN ag.preco ELSE 0 END), 2) as creditos_ganhos
FROM tutor t
JOIN aluno a ON t.nusp = a.nusp
LEFT JOIN agendamento ag ON ag.nusp_tutor = t.nusp
LEFT JOIN avaliacao av ON av.nusp_avaliado = t.nusp
GROUP BY t.nusp, a.pnome, a.mnome, a.fnome
ORDER BY aulas_concluidas DESC, avaliacao_media DESC;

-------------------------------------------------------------------------------
CREATE VIEW v_saldo_creditos_aluno AS
SELECT 
    a.nusp,
    a.pnome,
    a.mnome,
    a.fnome,
    a.qtd_creditos as creditos_totais,
    COALESCE(SUM(CASE 
        WHEN ag.status IN ('pendente') THEN ag.preco 
        ELSE 0 
    END), 0) as creditos_reservados,
    a.qtd_creditos - COALESCE(SUM(CASE 
        WHEN ag.status IN ('pendente') THEN ag.preco 
        ELSE 0 
    END), 0) as creditos_disponiveis
FROM aluno a
LEFT JOIN agendamento ag ON ag.nusp_solicitante = a.nusp
GROUP BY a.nusp, a.pnome, a.mnome, a.fnome, a.qtd_creditos;

-------------------------------------------------------------------------------
CREATE VIEW v_historico_compras_pacotes AS
SELECT 
    ap.nusp_comprador,
    a.pnome || ' ' || COALESCE(a.mnome || ' ', '') || a.fnome as nome_completo,
    ap.qtd_credito,
    ap.preco as preco_pago,
    p.preco as preco_original,
    ROUND(((p.preco - ap.preco) / p.preco) * 100, 2) as desconto_percentual,
    ap.timestamp_compra,
    ROUND(AVG(av.nota), 2) as avaliacao_media_epoca
FROM aluno_pacote ap
JOIN aluno a ON ap.nusp_comprador = a.nusp
JOIN pacote p ON ap.qtd_credito = p.qtd_credito
LEFT JOIN avaliacao av ON av.nusp_avaliado = ap.nusp_comprador 
    AND av.id_agendamento IN (
        SELECT id FROM agendamento WHERE data < ap.timestamp_compra::date
    )
GROUP BY ap.nusp_comprador, a.pnome, a.mnome, a.fnome, ap.qtd_credito, 
         ap.preco, p.preco, ap.timestamp_compra
ORDER BY ap.timestamp_compra DESC;

-------------------------------------------------------------------------------
CREATE VIEW v_disciplinas_mais_procuradas AS
SELECT 
    d.codigo,
    d.nome,
    COUNT(DISTINCT td.nusp_tutor) as qtd_tutores_disponiveis,
    COUNT(DISTINCT ag.id) as qtd_agendamentos_total,
    COUNT(DISTINCT CASE WHEN ag.status = 'concluido' THEN ag.id END) as qtd_aulas_concluidas,
    ROUND(AVG(CASE WHEN ag.status = 'concluido' THEN av.nota END), 2) as avaliacao_media_disciplina
FROM disciplina d
LEFT JOIN tutor_disciplina td ON td.cod_disciplina = d.codigo
LEFT JOIN agendamento ag ON ag.nusp_tutor = td.nusp_tutor
LEFT JOIN avaliacao av ON av.id_agendamento = ag.id
GROUP BY d.codigo, d.nome
ORDER BY qtd_aulas_concluidas DESC;