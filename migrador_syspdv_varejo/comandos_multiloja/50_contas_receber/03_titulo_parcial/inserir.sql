INSERT INTO titulo_a_receber (ttlr_id, ctr_id, ttlr_vencimento, ttlr_valor, ttlr_valor_liquido, ttlr_ordem, ttlr_prazo, ttlr_status, ttlr_saldo)
SELECT nextval('sq_titulo_a_receber'), c.ctr_id, c.ctr_primeiro_vencimento, c.ctr_valor_nominal, c.ctr_valor_nominal,
       1, 30, %(ttlr_status)s, c.ctr_valor_nominal
  FROM conta_a_receber c
 WHERE c.ctr_id = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'conta_receber' AND codigo_origem = %(ctr_id)s::text)
