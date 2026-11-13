-- Pentaho: "VF - Inserir Especie de Documento" (cria BOLETO PAGAR e BOLETO RECEBER se faltarem)
INSERT INTO especie_documento (edc_codigo, edc_descricao, edc_sigla, edc_tipo_limite, edc_genero, edc_controla_limite)
SELECT COALESCE((SELECT MAX(edc_codigo) + 1 FROM especie_documento), 1), 'BOLETO PAGAR', 'BP', 'AVULSO', 'P', 'f'
 WHERE COALESCE((SELECT edc_codigo FROM especie_documento
                  WHERE UPPER(edc_descricao) = 'BOLETO PAGAR' AND UPPER(edc_sigla) = 'BP'
                    AND UPPER(edc_genero) = 'P' AND edc_controla_limite = FALSE LIMIT 1), 0) = 0;

INSERT INTO especie_documento (edc_codigo, edc_descricao, edc_sigla, edc_tipo_limite, edc_genero, edc_controla_limite)
SELECT COALESCE((SELECT MAX(edc_codigo) + 1 FROM especie_documento), 1), 'BOLETO RECEBER', 'BR', 'AVULSO', 'R', 't'
 WHERE COALESCE((SELECT edc_codigo FROM especie_documento
                  WHERE UPPER(edc_descricao) = 'BOLETO RECEBER' AND UPPER(edc_sigla) = 'BR'
                    AND UPPER(edc_genero) = 'R' AND edc_controla_limite = TRUE LIMIT 1), 0) = 0;

-- Pentaho: T-Cliente-update-Loja (cliente sem loja recebe a loja matriz)
UPDATE pessoa_cliente
   SET loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
 WHERE loj_codigo IS NULL;

-- Pentaho: "update holcod pessoa" - todas as pessoas recebem o holcod da loja matriz.
UPDATE pessoa
   SET holcod = (SELECT p.holcod
                   FROM pessoa p
                  INNER JOIN pessoa_loja pl ON (pl.pes_codigo = p.pes_codigo)
                  WHERE pl.loj_matriz = 'S'
                  LIMIT 1)
