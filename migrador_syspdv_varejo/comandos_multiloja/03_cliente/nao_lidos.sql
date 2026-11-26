-- Clientes sem CPF/CNPJ: nao migram na loja adicional (sem documento nao ha como saber se ja existe na matriz).
SELECT CLICOD AS REGISTRO, CLIDES AS DESCRICAO, 'sem CPF/CNPJ: não é migrado na loja adicional' AS MOTIVO
  FROM CLIENTE
 WHERE REPLACE(CLICOD, '0', '') <> '' AND CLIDES IS NOT NULL
   AND (CLICPFCGC IS NULL OR CLICPFCGC = '')
 ORDER BY 1
