-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto
-- (no Pentaho era "proforlin = 'N'" fixo).

-- Pentaho: FB - PRODUTO_PRECO (T-Auditoria_Custo_inicial)
SELECT r.PRPCOD, p.PROCOD, p.PROPRCCST, p.PROPRCCSTFIS
  FROM PRODUTO p
 CROSS JOIN PROPRIO r
 WHERE p.PROPRCCST IS NOT NULL
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 2
