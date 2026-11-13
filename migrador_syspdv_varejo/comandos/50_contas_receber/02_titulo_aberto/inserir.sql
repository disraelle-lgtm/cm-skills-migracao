-- Valores da conta ja gravada (como no Pentaho: vencimento, valor e liquido = valor nominal; ordem 1, prazo 30)
INSERT INTO titulo_a_receber (ttlr_id, ctr_id, ttlr_vencimento, ttlr_valor, ttlr_valor_liquido, ttlr_ordem, ttlr_prazo, ttlr_status)
SELECT nextval('sq_titulo_a_receber'), c.ctr_id, c.ctr_primeiro_vencimento, c.ctr_valor_nominal, c.ctr_valor_nominal,
       1, 30, %(ttlr_status)s
  FROM conta_a_receber c
 WHERE c.ctr_id = %(ctr_id)s
