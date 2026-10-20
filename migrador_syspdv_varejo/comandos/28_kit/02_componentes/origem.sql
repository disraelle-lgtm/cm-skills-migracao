-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - COMPONENTE (T-Produto_Componentes_Composicao). Componente e kit migrados.
SELECT c.PROCOD, c.CNTCOD, c.CNTQTD, c.CNTPRCVDA1, c.CNTPRCVDA2, c.CNTPRCVDA3
  FROM COMPONENTE c
  JOIN PRODUTO p ON c.CNTCOD = p.PROCOD
  JOIN PRODUTO pai ON c.PROCOD = pai.PROCOD
 WHERE p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
   AND pai.PROCOMP = 'K'
   AND (COALESCE(pai.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 2
