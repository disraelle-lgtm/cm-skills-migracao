UPDATE pessoa
   SET holcod = (SELECT p.holcod FROM pessoa p INNER JOIN pessoa_loja pl ON (pl.pes_codigo = p.pes_codigo)
                  WHERE pl.loj_matriz = 'S' LIMIT 1)
 WHERE holcod IS NULL;

-- Acesso a loja nova para o administrador (1) e os usuarios de sistema (>= 1000000000), como no Pentaho (Loja-permissao)
INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo, pfl_principal)
SELECT nextval('sq_funcionario_loja'), pf.fun_codigo, {{loja_destino}}, 'S', FALSE
  FROM pessoa_funcionario pf
 WHERE (pf.fun_codigo = 1 OR pf.fun_codigo >= 1000000000)
   AND EXISTS (SELECT 1 FROM pessoa_loja WHERE loj_codigo = {{loja_destino}})
   AND NOT EXISTS (SELECT 1 FROM pessoa_funcionario_loja x WHERE x.fun_codigo = pf.fun_codigo AND x.loj_codigo = {{loja_destino}})
