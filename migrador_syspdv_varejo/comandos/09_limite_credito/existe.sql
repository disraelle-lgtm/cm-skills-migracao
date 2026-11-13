-- especie_boleto_receber: o limite ja aponta para BOLETO RECEBER? (false = migrado errado, ex.: BOLETO PAGAR -> atualiza)
SELECT (edc_codigo IS NOT DISTINCT FROM (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1)) AS especie_boleto_receber
     , lcr_situacao
  FROM limite_de_credito
 WHERE cli_codigo = %(cli_codigo)s
 LIMIT 1
