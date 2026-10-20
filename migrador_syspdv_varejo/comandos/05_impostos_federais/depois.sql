-- Pentaho: entrada SQL "VF - Imposto Federal Geral" do JOB-Migracao_inicial-Cadastros.
-- Diferenca proposital: cada INSERT so inclui o que ainda nao existe (NOT EXISTS), para
-- poder rodar de novo sem erro de chave duplicada. O UPDATE da _geral mantem as
-- aliquotas/situacoes iguais as da impostos_federais quando elas mudam numa nova rodada.

INSERT INTO impostos_federais_geral (impfedgeralid, impfedst, impfedalq, impfedstsai, impfedalqsai)
SELECT f.impfedgeralid, f.impfedst, f.impfedalq, f.impfedstsai, f.impfedalqsai
  FROM impostos_federais f
 WHERE f.impfedgeralid IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM impostos_federais_geral g WHERE g.impfedgeralid = f.impfedgeralid)
 ORDER BY 1;

UPDATE impostos_federais_geral g
   SET impfedst = f.impfedst, impfedalq = f.impfedalq
     , impfedstsai = f.impfedstsai, impfedalqsai = f.impfedalqsai
  FROM impostos_federais f
 WHERE f.impfedgeralid = g.impfedgeralid
   AND (g.impfedst, g.impfedalq, g.impfedstsai, g.impfedalqsai)
       IS DISTINCT FROM (f.impfedst, f.impfedalq, f.impfedstsai, f.impfedalqsai);

INSERT INTO impostos_federais_atacado (impfedatacadoid)
SELECT f.impfedatacadoid FROM impostos_federais f
 WHERE f.impfedatacadoid IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM impostos_federais_atacado a WHERE a.impfedatacadoid = f.impfedatacadoid)
 ORDER BY 1;

INSERT INTO impostos_federais_simples (impfedsimplesid)
SELECT f.impfedsimplesid FROM impostos_federais f
 WHERE f.impfedsimplesid IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM impostos_federais_simples s WHERE s.impfedsimplesid = f.impfedsimplesid)
 ORDER BY 1;

INSERT INTO impostos_federais_varejo (impfedvarejoid)
SELECT f.impfedvarejoid FROM impostos_federais f
 WHERE f.impfedvarejoid IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM impostos_federais_varejo v WHERE v.impfedvarejoid = f.impfedvarejoid)
 ORDER BY 1;

-- Igual ao Pentaho: acerta as sequences para depois do maior ID gravado.
SELECT SETVAL('sq_impostos_federais_geral', COALESCE((SELECT MAX(impfedgeralid) FROM impostos_federais_geral), 0) + 1, FALSE);
SELECT SETVAL('sq_impostos_federais_atacado', COALESCE((SELECT MAX(impfedatacadoid) FROM impostos_federais_atacado), 0) + 1, FALSE);
SELECT SETVAL('sq_impostos_federais_simples', COALESCE((SELECT MAX(impfedsimplesid) FROM impostos_federais_simples), 0) + 1, FALSE);
SELECT SETVAL('sq_impostos_federais_varejo', COALESCE((SELECT MAX(impfedvarejoid) FROM impostos_federais_varejo), 0) + 1, FALSE)
