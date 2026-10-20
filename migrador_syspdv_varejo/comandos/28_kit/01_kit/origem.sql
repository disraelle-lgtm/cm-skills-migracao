-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - KIT (T-Produto_Kit_inicial). DISTINCT: o Pentaho lia uma linha por componente e
-- gravava a mesma composicao varias vezes.
SELECT DISTINCT p.PROCOD, c.CNTTIP
  FROM PRODUTO p
 INNER JOIN COMPONENTE c ON p.PROCOD = c.PROCOD
 WHERE p.PROCOMP = 'K'
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
