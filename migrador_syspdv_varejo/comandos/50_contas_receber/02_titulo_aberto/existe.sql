-- Pentaho: chave ctr_id (so insere)
SELECT ttlr_id FROM titulo_a_receber WHERE ctr_id = %(ctr_id)s ORDER BY ttlr_id LIMIT 1
