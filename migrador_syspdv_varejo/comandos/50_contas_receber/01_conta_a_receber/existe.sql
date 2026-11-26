-- Pentaho: chave (cliente, documento, id); so a loja tem Update = Y
SELECT (edc_codigo IS NOT DISTINCT FROM (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1)) AS especie_ok, loj_codigo FROM conta_a_receber WHERE ctr_id = %(ctr_id)s
