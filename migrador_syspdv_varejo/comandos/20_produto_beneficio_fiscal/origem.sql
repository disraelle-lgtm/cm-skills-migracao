-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.
-- Pentaho: FB - PRODUTO (T-Produto_Codigo_Beneficio_fiscal_inicial / _virada): produtos com codigo de
-- beneficio fiscal. Aqui so de produtos que sao migrados (o Pentaho nao filtrava: produto nao migrado
-- daria erro de chave no VarejoFacil).
SELECT p.PROCOD
     , p.PROBENFIS
     , (SELECT r.PRPCOD FROM PROPRIO r) AS PRPCOD
  FROM PRODUTO p
 WHERE p.PROBENFIS IS NOT NULL
   AND p.PROBENFIS <> ''
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
