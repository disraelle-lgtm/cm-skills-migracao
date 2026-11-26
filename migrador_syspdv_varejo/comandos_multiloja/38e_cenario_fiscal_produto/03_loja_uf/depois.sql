-- Loja adicional: a loja nova ENTRA nos cenarios fiscais por produto. Os vinculos da matriz nao sao movidos (o item
-- da migracao normal move todos para a matriz).
INSERT INTO cenario_fiscal_produto_loja (cfp_codigo, loj_codigo)
SELECT c.cfp_codigo, {{loja_destino}}
  FROM cenario_fiscal_produto c
 WHERE NOT EXISTS (SELECT 1 FROM cenario_fiscal_produto_loja l WHERE l.cfp_codigo = c.cfp_codigo AND l.loj_codigo = {{loja_destino}})
