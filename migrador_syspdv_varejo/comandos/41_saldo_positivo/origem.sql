-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto
-- (no Pentaho era "proforlin = 'N'" fixo).

-- Pentaho: FB - PRODUTO (T-MovimentacaoEstoque_positivo_inicial)
SELECT t1.PROCOD
     , ABS(t2.ESTATUSDO) AS SALDO
     , (SELECT r.PRPCOD FROM PROPRIO r) AS LOJCOD
  FROM PRODUTO t1
  JOIN ESTOQUE t2 ON t1.PROCOD = t2.PROCOD
 WHERE t2.ESTATUSDO >= 0
   AND t1.PRODES IS NOT NULL
   AND t1.PROCOD <> '00000000000000'
   AND (COALESCE(t1.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY t1.PROCOD
