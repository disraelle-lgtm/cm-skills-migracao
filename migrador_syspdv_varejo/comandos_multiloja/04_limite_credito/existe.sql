-- Loja adicional: o cliente no VarejoFacil vem do vinculo desta loja.
SELECT (edc_codigo IS NOT DISTINCT FROM (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1)) AS especie_boleto_receber
     , lcr_situacao
  FROM limite_de_credito
 WHERE cli_codigo = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text)
 LIMIT 1
