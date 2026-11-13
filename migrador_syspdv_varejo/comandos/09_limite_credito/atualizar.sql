UPDATE limite_de_credito
   SET edc_codigo = (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1), lcr_situacao = %(lcr_situacao)s
 WHERE cli_codigo = %(cli_codigo)s
