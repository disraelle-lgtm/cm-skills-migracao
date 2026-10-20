-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - TRIBUTACAO-PROPRIO (T-ItemTabelaTributaria2). Percentuais da NF calculados como no
-- Pentaho. So as tributacoes usadas pelos produtos migrados (as outras nao tem situacao fiscal,
-- e o Pentaho as descartava no Join Rows).
SELECT CASE WHEN t.TRBSIM = 'T' THEN 100 WHEN t.TRBSIM = 'R' THEN 100 - t.TRBRED ELSE 0 END AS TRIBUTADA
     , CASE WHEN t.TRBSIM = 'F' THEN 100 WHEN t.TRBRED > 0 THEN 100 - t.TRBRED ELSE 0 END AS OUTROS
     , CASE WHEN t.TRBSIM = 'I' THEN 100 WHEN t.TRBSIM = 'N' THEN 100 ELSE 0 END AS ISENTO
     , t.TRBALQ AS ALICOTA
     , t.TRBTABBCUP AS CST
     , LEFT(t.TRBCFOPSAI, 4) AS CFOP
     , t.TRBID AS TRIBUTACAO
     , r.PRPUF AS ORIGEM
  FROM TRIBUTACAO t
     , PROPRIO r
 WHERE t.TRBID IN (SELECT p.TRBID FROM PRODUTO p
                    WHERE p.PRODES IS NOT NULL
                      AND p.PROCOD <> '00000000000000'
                      AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1))
 ORDER BY 7
