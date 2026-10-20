-- O funcionario e localizado pela pessoa_funcionario (permanente). O Pentaho usava uma coluna
-- temporaria (fun_codigo_syspdv) apagada no fim, e duplicava a pessoa numa segunda execucao.
SELECT pf.fun_cargo_syspdv, pf.fun_limite_desconto, pf.fun_comissao1, pf.fun_comissao2
     , pf.fun_comissao3, pf.fun_tipo_preco_padrao, pf.fun_comissao_por_metas, pf.fun_inativo
     , pf.fun_ace, pfl.pfl_ativo
     , (pfl.loj_codigo IS NOT DISTINCT FROM (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)) AS loja_matriz_ok
  FROM pessoa_funcionario pf
  LEFT JOIN pessoa_funcionario_loja pfl ON (pfl.fun_codigo = pf.fun_codigo)
 WHERE pf.fun_codigo = %(funcod)s
 LIMIT 1
