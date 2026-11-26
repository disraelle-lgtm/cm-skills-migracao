-- (v2026.11.61) A especie e procurada PELO NOME (BOLETO PAGAR) - antes o codigo era fixo (1), o que so vale numa base
-- vazia (o item Cliente cria BOLETO PAGAR = 1 e BOLETO RECEBER = 2). Numa base que ja tinha especies, os codigos eram
-- outros (caso real: BOLETO RECEBER = 3) e o titulo ia com a especie errada. Cria a especie se faltar (igual ao Cliente).
INSERT INTO especie_documento (edc_codigo, edc_descricao, edc_sigla, edc_tipo_limite, edc_genero, edc_controla_limite)
SELECT COALESCE((SELECT MAX(edc_codigo) + 1 FROM especie_documento), 1), 'BOLETO PAGAR', 'BP', 'AVULSO', 'P', 'f'
 WHERE NOT EXISTS (SELECT 1 FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO PAGAR')
