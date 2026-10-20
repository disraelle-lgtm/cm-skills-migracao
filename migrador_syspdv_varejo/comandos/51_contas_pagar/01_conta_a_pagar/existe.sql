-- Pentaho: chave (id, documento); tudo com Update = N (so insere)
SELECT ctp_id FROM conta_a_pagar WHERE ctp_id = %(ctp_id)s
