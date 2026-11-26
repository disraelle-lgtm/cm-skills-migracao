-- Titulo ja migrado com a especie errada (versao anterior a 2026.11.61): corrige so a especie.
UPDATE conta_a_pagar SET edc_codigo = (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO PAGAR' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BP') DESC, (UPPER(TRIM(edc_genero)) = 'P') DESC, edc_codigo LIMIT 1) WHERE ctp_id = %(ctp_id)s
