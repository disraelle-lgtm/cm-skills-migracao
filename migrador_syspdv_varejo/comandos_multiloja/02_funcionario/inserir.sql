-- Funcionario NOVO: proximo codigo livre (< 1000000000), principal na loja nova, vinculo novo = TRUE.
-- O CPF de uma pessoa que nao e funcionario (ex.: cliente da matriz) e reaproveitado sem alterar a pessoa.
WITH pessoa_existente AS (
    SELECT pes_codigo FROM pessoa
     WHERE NULLIF(%(pes_num_documento)s::varchar, '') IS NOT NULL AND pes_num_documento = %(pes_num_documento)s::varchar
     ORDER BY pes_codigo LIMIT 1
), nova_pessoa AS (                                     -- T-Funcionario-Pessoa
    INSERT INTO pessoa (pes_codigo, pes_nome, pes_fantasia, pes_num_documento, pes_tipo)
    SELECT nextval('sq_pessoa'), %(pes_nome)s, %(pes_fantasia)s, %(pes_num_documento)s::varchar, 'FISICA'
     WHERE NOT EXISTS (SELECT 1 FROM pessoa_existente)
    RETURNING pes_codigo
), pessoa_final AS (
    SELECT pes_codigo FROM pessoa_existente UNION ALL SELECT pes_codigo FROM nova_pessoa
), novo_funcionario AS (                                -- T-Funcionario-PessoaFuncionario
    INSERT INTO pessoa_funcionario (fun_codigo, pes_codigo, fun_cargo_syspdv, fun_limite_desconto
                                  , fun_comissao1, fun_comissao2, fun_comissao3, fun_tipo_preco_padrao
                                  , fun_comissao_por_metas, fun_inativo, fun_ace)
    SELECT (SELECT COALESCE(MAX(fun_codigo), 0) + 1 FROM pessoa_funcionario WHERE fun_codigo < 1000000000), pes_codigo, %(fun_cargo_syspdv)s, %(fun_limite_desconto)s
         , %(fun_comissao1)s, %(fun_comissao2)s, %(fun_comissao3)s, %(fun_tipo_preco_padrao)s
         , %(fun_comissao_por_metas)s, %(fun_inativo)s, %(fun_ace)s
      FROM pessoa_final
    RETURNING fun_codigo
), vinc AS (
    INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
    SELECT {{loja_destino}}, 'funcionario', %(funcod)s::text, fun_codigo, TRUE FROM novo_funcionario
    RETURNING 1
)
INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo, pfl_principal)
SELECT nextval('sq_funcionario_loja'), fun_codigo, {{loja_destino}}, %(pfl_ativo)s, TRUE
  FROM novo_funcionario
