-- Especie = BOLETO RECEBER procurada pelo NOME (o codigo varia: numa base que ja tinha especies ela pode ser 3,
-- e o 2 fixo de antes gravava BOLETO PAGAR).
INSERT INTO limite_de_credito (lcr_id, cli_codigo, lcr_valor, edc_codigo, lcr_situacao)
VALUES (nextval('sq_limite_credito'), %(cli_codigo)s, %(lcr_valor)s, (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1), %(lcr_situacao)s)
