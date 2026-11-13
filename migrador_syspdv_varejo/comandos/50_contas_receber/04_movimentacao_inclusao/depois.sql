-- Pentaho: T-MovimentacaoInclusaoTituloReceber_inicial - uma INCLUSAO_DE_TITULO por titulo (chave ttlr_id)
INSERT INTO movimentacao_titulo_receber (mov_id, mov_operacao, ttlr_id, mov_valor, mov_data, mov_data_de_registro, mov_usuario)
SELECT nextval('sq_movimentacao_titulo_recb'), 'INCLUSAO_DE_TITULO', tr.ttlr_id, tr.ttlr_valor,
       cr.ctr_data_emissao, cr.ctr_data_emissao, 1
  FROM titulo_a_receber tr
 INNER JOIN conta_a_receber cr ON tr.ctr_id = cr.ctr_id
 WHERE NOT EXISTS (SELECT 1 FROM movimentacao_titulo_receber m WHERE m.ttlr_id = tr.ttlr_id)
