-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - ITEM_SIMILARES (so de produtos migrados)
SELECT its.PROCOD, its.PROCODSIM
  FROM ITEM_SIMILARES its
  JOIN PRODUTO p ON its.PROCOD = p.PROCOD
 WHERE p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
