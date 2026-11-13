SELECT 1 WHERE (SELECT t.ttlr_id FROM titulo_a_receber t WHERE t.ctr_id = %(ctr_id)s AND t.ttlr_status = 'PARCIALMENTE_LIQUIDADO' ORDER BY t.ttlr_id LIMIT 1) IS NOT NULL
