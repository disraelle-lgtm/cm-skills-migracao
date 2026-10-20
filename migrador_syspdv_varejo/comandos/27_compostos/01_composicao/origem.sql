-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - COMPOSTO (T-Produto_Composicao_inicial)
SELECT c.PROCOD, c.CMPQTD, c.CMPESTVEN
  FROM COMPOSTO c
  JOIN PRODUTO p ON c.PROCOD = p.PROCOD
 WHERE p.PROCOMP = 'S'
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
