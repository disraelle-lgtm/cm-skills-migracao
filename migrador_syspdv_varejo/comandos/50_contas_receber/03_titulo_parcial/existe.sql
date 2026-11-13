-- No Pentaho o titulo parcial era ligado a conta pelo NUMERO DO DOCUMENTO (CTRNUM): com o mesmo
-- numero em outro cliente, o titulo aberto do outro cliente virava "parcialmente liquidado".
-- Aqui a ligacao e pelo id (ctr_id = CTRID). Pentaho: chave ctr_id; status com Update = Y
SELECT ttlr_status FROM titulo_a_receber WHERE ctr_id = %(ctr_id)s ORDER BY ttlr_id LIMIT 1
