-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - PRODUTO (T-CriaSituacaoFiscalProduto): uma situacao fiscal por tributacao usada
SELECT p.TRBID
  FROM PRODUTO p
 WHERE p.TRBID IS NOT NULL
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 GROUP BY p.TRBID
 ORDER BY 1
