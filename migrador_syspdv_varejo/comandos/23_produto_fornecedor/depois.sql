-- Pentaho: SQLs do JOB-Produto_Fornecedor_inicial, na mesma ordem.

-- "VF - Define Principal": um fornecedor principal (P) por produto; os demais secundarios (S)
UPDATE produto_fornecedor
   SET prfnivel = 'S'
 WHERE prfid NOT IN (SELECT MIN(prfid)
                       FROM produto_fornecedor
                      WHERE prfid IN (SELECT prfid FROM produto_fornecedor
                                       WHERE prfnivel = 'P'
                                         AND procod IN (SELECT procod FROM produto_fornecedor
                                                         WHERE prfnivel = 'P'
                                                         GROUP BY procod HAVING COUNT(procod) >= 1))
                      GROUP BY procod);
UPDATE produto_fornecedor
   SET prfnivel = 'P'
 WHERE prfnivel = 'S'
   AND procod IN (SELECT procod FROM produto_fornecedor GROUP BY procod HAVING COUNT(*) = 1);

-- "VF - Limpa": referencia numerica sem zeros a esquerda (o transformar.py ja grava assim;
-- fica aqui para referencias que ja estavam no banco). Limite de 18 digitos: acima disso o
-- CAST AS BIGINT do Pentaho daria erro.
UPDATE produto_fornecedor SET prfreffor = CAST(prfreffor AS bigint)
 WHERE prfreffor ~ '^[0-9]{1,18}$' AND prfreffor <> CAST(CAST(prfreffor AS bigint) AS varchar);

-- "VF - Limpa Duplicidade" do Pentaho so monta o texto de DELETEs num SELECT e nao executa
-- nada; aqui nao existe duplicidade (a chave e produto + fornecedor + referencia).
-- "VF - Define ref principal" (mesmo SQL do Define Principal, rodado de novo)
UPDATE produto_fornecedor
   SET prfnivel = 'S'
 WHERE prfid NOT IN (SELECT MIN(prfid)
                       FROM produto_fornecedor
                      WHERE prfid IN (SELECT prfid FROM produto_fornecedor
                                       WHERE prfnivel = 'P'
                                         AND procod IN (SELECT procod FROM produto_fornecedor
                                                         WHERE prfnivel = 'P'
                                                         GROUP BY procod HAVING COUNT(procod) >= 1))
                      GROUP BY procod);
UPDATE produto_fornecedor
   SET prfnivel = 'P'
 WHERE prfnivel = 'S'
   AND procod IN (SELECT procod FROM produto_fornecedor GROUP BY procod HAVING COUNT(*) = 1);

SET session_replication_role = DEFAULT
