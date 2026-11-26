-- Pentaho: chave (id, documento); tudo com Update = N (so insere)
SELECT (edc_codigo IS NOT DISTINCT FROM (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO PAGAR' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BP') DESC, (UPPER(TRIM(edc_genero)) = 'P') DESC, edc_codigo LIMIT 1)) AS especie_ok, ctp_id FROM conta_a_pagar WHERE ctp_id = %(ctp_id)s
