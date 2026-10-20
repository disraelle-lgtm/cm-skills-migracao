-- Um comando so grava as 3 tabelas (as 3 transformacoes do Pentaho). Se der erro, nada
-- desta linha fica gravado.
WITH nova_pessoa AS (                                   -- T-Funcionario-Pessoa
    INSERT INTO pessoa (pes_codigo, pes_nome, pes_fantasia, pes_num_documento, pes_tipo)
    VALUES (nextval('sq_pessoa'), %(pes_nome)s, %(pes_fantasia)s, %(pes_num_documento)s, 'FISICA')
    RETURNING pes_codigo
), novo_funcionario AS (                                -- T-Funcionario-PessoaFuncionario
    INSERT INTO pessoa_funcionario (fun_codigo, pes_codigo, fun_cargo_syspdv, fun_limite_desconto
                                  , fun_comissao1, fun_comissao2, fun_comissao3, fun_tipo_preco_padrao
                                  , fun_comissao_por_metas, fun_inativo, fun_ace)
    SELECT %(funcod)s, pes_codigo, %(fun_cargo_syspdv)s, %(fun_limite_desconto)s
         , %(fun_comissao1)s, %(fun_comissao2)s, %(fun_comissao3)s, %(fun_tipo_preco_padrao)s
         , %(fun_comissao_por_metas)s, %(fun_inativo)s, %(fun_ace)s
      FROM nova_pessoa
    RETURNING fun_codigo
)                                                       -- T-Funcionario-Loja (loja matriz do VarejoFacil)
INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo)
SELECT nextval('sq_funcionario_loja'), fun_codigo, (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1), %(pfl_ativo)s
  FROM novo_funcionario
