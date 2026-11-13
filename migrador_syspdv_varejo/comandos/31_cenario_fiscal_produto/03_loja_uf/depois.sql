-- Pentaho: T-cenario_fiscal_produto_loja + T-cenario_fiscal_produto_uf_destino.
-- No Pentaho a loja era a CONSTANTE 1 fixa no .ktr; aqui e a loja matriz.
INSERT INTO cenario_fiscal_produto_loja (cfp_codigo, loj_codigo)
SELECT c.cfp_codigo, (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
  FROM cenario_fiscal_produto c
 WHERE NOT EXISTS (SELECT 1 FROM cenario_fiscal_produto_loja l WHERE l.cfp_codigo = c.cfp_codigo);
UPDATE cenario_fiscal_produto_loja SET loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
 WHERE loj_codigo IS DISTINCT FROM (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1);

INSERT INTO cenario_fiscal_produto_uf_destino (cfp_codigo, uf_destino)
SELECT t2.cfp_codigo, t3.pes_uf
  FROM pessoa_loja t1
  JOIN cenario_fiscal_produto_loja t2 ON t1.loj_codigo = t2.loj_codigo
  JOIN pessoa t3 ON t1.pes_codigo = t3.pes_codigo
 WHERE t1.loj_matriz = 'S'
   AND NOT EXISTS (SELECT 1 FROM cenario_fiscal_produto_uf_destino u WHERE u.cfp_codigo = t2.cfp_codigo);
UPDATE cenario_fiscal_produto_uf_destino u SET uf_destino = t3.pes_uf
  FROM pessoa_loja t1 JOIN pessoa t3 ON t1.pes_codigo = t3.pes_codigo
 WHERE t1.loj_matriz = 'S' AND u.uf_destino IS DISTINCT FROM t3.pes_uf
