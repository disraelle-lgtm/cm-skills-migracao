-- Pentaho: SQLs finais do JOB-Pessoas_inicial, na mesma ordem.

-- "VF - Corrige Tipo Documento"
UPDATE pessoa SET pes_num_documento = LPAD(pes_num_documento, 11, '0')
 WHERE pes_tipo = 'FISICA' AND LENGTH(pes_num_documento) < 11;
UPDATE pessoa SET pes_tipo = 'JURIDICA', pes_num_documento = LPAD(pes_num_documento, 14, '0')
 WHERE pes_tipo = 'FISICA' AND LENGTH(pes_num_documento) > 11;
UPDATE pessoa SET pes_num_documento = LPAD(pes_num_documento, 14, '0')
 WHERE pes_tipo = 'JURIDICA' AND LENGTH(pes_num_documento) > 11 AND LENGTH(pes_num_documento) < 14;
UPDATE pessoa SET pes_tipo = 'FISICA', pes_num_documento = LPAD(pes_num_documento, 11, '0')
 WHERE pes_tipo = 'JURIDICA' AND LENGTH(pes_num_documento) <= 11;

-- "VF - Update Holcod"
UPDATE pessoa
   SET holcod = (SELECT t1.holcod FROM pessoa t1
                   JOIN pessoa_loja t2 ON (t2.pes_codigo = t1.pes_codigo)
                  WHERE t2.loj_matriz = 'S' LIMIT 1);

-- "VF - Corrige IE Duplicada": IE repetida entre pessoas vira ISENTO.
-- No Pentaho havia "pes_codigo != 21" fixo (a pessoa da loja naquele cliente); aqui a
-- excecao e a pessoa de qualquer loja, que nunca tem a IE trocada nem conta na repeticao.
UPDATE pessoa
   SET pes_num_identificacao = 'ISENTO'
 WHERE pes_codigo NOT IN (SELECT pes_codigo FROM pessoa_loja WHERE pes_codigo IS NOT NULL)
   AND pes_num_identificacao IN (SELECT pes_num_identificacao
                                   FROM pessoa
                                  WHERE pes_num_identificacao != 'ISENTO'
                                    AND pes_codigo NOT IN (SELECT pes_codigo FROM pessoa_loja WHERE pes_codigo IS NOT NULL)
                                  GROUP BY pes_num_identificacao
                                 HAVING COUNT(pes_num_identificacao) > 1);

-- "VF - Corrige Tipo Contribuinte"
UPDATE pessoa SET pes_tipo_contribuinte = 'CONTRIBUINTE'
 WHERE pes_tipo = 'JURIDICA' AND pes_num_identificacao != 'ISENTO';

-- "VF - Atualiza a sequence" (pes_codigo a partir de 4444444 e faixa reservada do VarejoFacil)
SELECT SETVAL('sq_pessoa', COALESCE((SELECT MAX(pes_codigo) FROM pessoa WHERE pes_codigo < 4444444), 0) + 1, FALSE);
SELECT SETVAL('sq_categoria_financeira', COALESCE((SELECT MAX(cfnc_codigo) FROM categoria_financeira), 0) + 1, FALSE);

-- "VF - Ajustes campos"
UPDATE pessoa SET pes_bairro = 'SEM DESCRICAO' WHERE pes_bairro IS NULL OR pes_bairro = '';
UPDATE pessoa SET pes_data_cadastro = CURRENT_DATE WHERE pes_data_cadastro IS NULL;
UPDATE pessoa SET pes_data_alteracao = CURRENT_DATE WHERE pes_data_alteracao IS NULL;
UPDATE pessoa SET pes_fantasia = pes_nome WHERE pes_fantasia IS NULL;
UPDATE pessoa SET pes_tipo = 'JURIDICA' WHERE pes_tipo = 'J';
UPDATE pessoa SET pes_tipo = 'FISICA' WHERE pes_tipo = 'F';
UPDATE pessoa_cliente SET cli_comp_estado_civil = 'OUTROS' WHERE cli_comp_estado_civil IS NULL;
UPDATE pessoa_cliente SET cli_comp_desc_concedido = 0 WHERE cli_comp_desc_concedido IS NULL;
UPDATE pessoa_fornecedor SET for_prazo_entrega = 0 WHERE for_prazo_entrega IS NULL;
UPDATE pessoa_fornecedor SET ret_codigo = 1 WHERE ret_codigo IS NULL;
UPDATE pessoa_cliente SET cli_comp_orgao_publico = 'N' WHERE cli_comp_orgao_publico IS NULL;
UPDATE pessoa_cliente SET cli_comp_retem_iss = 'N' WHERE cli_comp_retem_iss IS NULL
