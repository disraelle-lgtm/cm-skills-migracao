-- Garante a especie BOLETO RECEBER (criada como nos Ajustes do Cliente, com o proximo codigo livre, se faltar):
-- o limite de credito do cliente e SEMPRE BOLETO RECEBER, qualquer que seja o codigo dela no VarejoFacil.
INSERT INTO especie_documento (edc_codigo, edc_descricao, edc_sigla, edc_tipo_limite, edc_genero, edc_controla_limite)
SELECT COALESCE((SELECT MAX(edc_codigo) + 1 FROM especie_documento), 1), 'BOLETO RECEBER', 'BR', 'AVULSO', 'R', 't'
 WHERE COALESCE((SELECT edc_codigo FROM especie_documento
                  WHERE UPPER(edc_descricao) = 'BOLETO RECEBER' AND UPPER(edc_sigla) = 'BR'
                    AND UPPER(edc_genero) = 'R' AND edc_controla_limite = TRUE LIMIT 1), 0) = 0;
