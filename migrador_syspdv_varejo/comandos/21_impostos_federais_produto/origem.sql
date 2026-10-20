-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.
-- Pentaho: FB - impostos_federais_produto (so de produtos que sao migrados)
SELECT i.IMPFEDSIM
     , i.PROCOD
  FROM IMPOSTOS_FEDERAIS_PRODUTO i
 WHERE i.PROCOD IN (SELECT p.PROCOD FROM PRODUTO p
                     WHERE p.PRODES IS NOT NULL
                       AND p.PROCOD <> '00000000000000'
                       AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1))
 ORDER BY 2, 1
