-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.
-- Pentaho: FB - PRODUTO_FORNECEDOR (T-ProdutoFornecedor_inicial)
SELECT pf.PROCOD, pf.FORCOD, pf.PRFREFFOR, pf.PRFUNID, pf.PRFQTD, pf.PRFNIVEL, f.FORCGC
  FROM PRODUTO_FORNECEDOR pf
  JOIN FORNECEDOR f ON pf.FORCOD = f.FORCOD
  JOIN PRODUTO p ON pf.PROCOD = p.PROCOD
 WHERE pf.FORCOD <> '0000'
   AND pf.PROCOD NOT LIKE '% %'
   AND f.FORCGC IS NOT NULL
   AND f.FORCGC <> ''
   AND pf.PRFREFFOR NOT IN ('00000000000000', '')
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1, 2, 3
