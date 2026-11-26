-- Fornecedors sem CPF/CNPJ: nao migram na loja adicional (sem documento nao ha como saber se ja existe na matriz).
SELECT FORCOD AS REGISTRO, FORDES AS DESCRICAO, 'sem CPF/CNPJ: não é migrado na loja adicional' AS MOTIVO
  FROM FORNECEDOR
 WHERE REPLACE(FORCOD, '0', '') <> ''
   AND (FORCGC IS NULL OR FORCGC = '')
 ORDER BY 1
