-- Pentaho: T-Cenario_fiscal_ncm_loja + T-Cenario_Fiscal_ncm_uf_destino.
-- No Pentaho a loja era a CONSTANTE 1 fixa no .ktr; aqui e a loja matriz.
INSERT INTO cenario_fiscal_ncm_loja (cfn_codigo, loj_codigo)
SELECT c.cfn_codigo, (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
  FROM cenario_fiscal_ncm c
 WHERE NOT EXISTS (SELECT 1 FROM cenario_fiscal_ncm_loja l WHERE l.cfn_codigo = c.cfn_codigo);
UPDATE cenario_fiscal_ncm_loja SET loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
 WHERE loj_codigo IS DISTINCT FROM (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1);

INSERT INTO cenario_fiscal_ncm_uf_destino (cfn_codigo, uf_destino)
SELECT t2.cfn_codigo, t3.pes_uf
  FROM pessoa_loja t1
  JOIN cenario_fiscal_ncm_loja t2 ON t1.loj_codigo = t2.loj_codigo
  JOIN pessoa t3 ON t1.pes_codigo = t3.pes_codigo
 WHERE t1.loj_matriz = 'S'
   AND NOT EXISTS (SELECT 1 FROM cenario_fiscal_ncm_uf_destino u WHERE u.cfn_codigo = t2.cfn_codigo)
