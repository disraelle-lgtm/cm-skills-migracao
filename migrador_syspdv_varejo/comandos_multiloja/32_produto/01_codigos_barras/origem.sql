-- Todos os codigos de barras de cada produto da loja adicional: os de PRODUTOAUX e o proprio codigo quando e EAN
-- (> 999999). SQL comum a Firebird e SQL Server; o filtro de produto segue fora de linha / movimentacao (ancora).
SELECT a.PROCOD, a.PROCODAUX AS EAN
  FROM PRODUTOAUX a JOIN PRODUTO p ON p.PROCOD = a.PROCOD
 WHERE p.PRODES IS NOT NULL AND REPLACE(p.PROCOD, '0', '') <> '' AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
UNION ALL
SELECT p.PROCOD, p.PROCOD AS EAN
  FROM PRODUTO p
 WHERE p.PROCOD > '00000000999999' AND p.PRODES IS NOT NULL AND REPLACE(p.PROCOD, '0', '') <> '' AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
