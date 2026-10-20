UPDATE limite_de_credito
   SET edc_codigo = %(edc_codigo)s, lcr_situacao = %(lcr_situacao)s
 WHERE cli_codigo = %(cli_codigo)s
