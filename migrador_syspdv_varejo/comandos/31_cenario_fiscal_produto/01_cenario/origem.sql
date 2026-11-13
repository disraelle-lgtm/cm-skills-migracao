-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: SF - CLASSIFICACAO TRIBUTARIA(Produto) (T-cenario_fiscal_produto_inicial):
-- classificacoes de produtos que sao diferentes da classificacao do NCM do produto
SELECT t1.CLATRBCODNFCE, t2.ID_NUM, t2.CSTCOD
  FROM PRODUTO t1
  LEFT JOIN CLASSIFICACAO_TRIBUTARIA t2 ON t1.CLATRBCODNFCE = t2.CLATRBCOD
  JOIN NCM t3 ON t1.PRONCM = t3.NCMCOD
 WHERE COALESCE(TRIM(t1.CLATRBCODNFCE), '') <> COALESCE(TRIM(t3.CLATRBCODNFCE), '')
   AND t1.PRODES IS NOT NULL
   AND t1.PROCOD <> '00000000000000'
   AND (COALESCE(t1.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 GROUP BY t1.CLATRBCODNFCE, t2.ID_NUM, t2.CSTCOD
 ORDER BY 1
