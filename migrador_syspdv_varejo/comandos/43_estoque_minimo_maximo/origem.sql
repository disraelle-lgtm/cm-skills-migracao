-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto
-- (no Pentaho era "proforlin = 'N'" fixo).

-- Pentaho: FB - PRODUTO (T-MovimentacaoEstoque_mininoemaximo_inicial). O "FB - Ajustes campos
-- estourados" zerava minimo/maximo acima de 100000 no SysPDV; aqui na leitura.
SELECT t1.PROCOD
     , CASE WHEN t1.PROESTMIN > 100000 THEN 0 ELSE t1.PROESTMIN END AS PROESTMIN
     , CASE WHEN t1.PROESTMAX > 100000 THEN 0 ELSE t1.PROESTMAX END AS PROESTMAX
     , (SELECT r.PRPCOD FROM PROPRIO r) AS LOJCOD
  FROM PRODUTO t1
 WHERE t1.PRODES IS NOT NULL
   AND t1.PROCOD <> '00000000000000'
   AND (COALESCE(t1.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
