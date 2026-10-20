-- Pentaho: atualiza os campos com Update = Y da pessoa_funcionario e o vinculo com a loja
-- (cria o vinculo se ainda nao existir). Os dados da pessoa nao sao atualizados (Update = N).
WITH funcionario AS (
    UPDATE pessoa_funcionario
       SET fun_cargo_syspdv = %(fun_cargo_syspdv)s, fun_limite_desconto = %(fun_limite_desconto)s
         , fun_comissao1 = %(fun_comissao1)s, fun_comissao2 = %(fun_comissao2)s
         , fun_comissao3 = %(fun_comissao3)s, fun_tipo_preco_padrao = %(fun_tipo_preco_padrao)s
         , fun_comissao_por_metas = %(fun_comissao_por_metas)s, fun_inativo = %(fun_inativo)s
         , fun_ace = %(fun_ace)s
     WHERE fun_codigo = %(funcod)s
    RETURNING fun_codigo
), vinculo AS (
    UPDATE pessoa_funcionario_loja
       SET loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1), pfl_ativo = %(pfl_ativo)s
     WHERE fun_codigo = %(funcod)s
    RETURNING fun_codigo
)
INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo)
SELECT nextval('sq_funcionario_loja'), fun_codigo, (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1), %(pfl_ativo)s
  FROM funcionario
 WHERE NOT EXISTS (SELECT 1 FROM vinculo)
