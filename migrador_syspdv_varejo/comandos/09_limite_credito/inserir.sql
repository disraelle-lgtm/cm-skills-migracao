INSERT INTO limite_de_credito (lcr_id, cli_codigo, lcr_valor, edc_codigo, lcr_situacao)
VALUES (nextval('sq_limite_credito'), %(cli_codigo)s, %(lcr_valor)s, %(edc_codigo)s, %(lcr_situacao)s)
