-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.
-- Pentaho: SQL - PRODUTOAUX (so de produtos que sao migrados)
SELECT px.PROCODAUX
     , px.PROCOD
     , px.PROFATORMULT
  FROM PRODUTOAUX px
  JOIN PRODUTO p ON px.PROCOD = p.PROCOD
 WHERE p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 2
