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

-- "VF - Limpa Duplicidade" (v2026.11.59, pedido do usuario): o Pentaho so MONTAVA o texto dos DELETE num SELECT e
-- nao executava. Aqui executa, com o mesmo resultado: o MESMO produto + fornecedor + referencia gravado mais de uma vez
-- fica com o registro de menor prfid. Roda depois do "VF - Limpa" porque e ele que cria a duplicidade ('0123' e '123'
-- do mesmo produto viram iguais). Nao trata a mesma referencia em produtos DIFERENTES (outra situacao).
DELETE FROM produto_fornecedor pf
 USING (SELECT procod, forcod, prfreffor, MIN(prfid) AS manter
          FROM produto_fornecedor
         GROUP BY procod, forcod, prfreffor
        HAVING COUNT(*) > 1) d
 WHERE pf.procod = d.procod AND pf.forcod = d.forcod AND pf.prfreffor = d.prfreffor
   AND pf.prfid <> d.manter;

-- MESMA referencia do fornecedor em produtos DIFERENTES (v2026.11.60, pedido do usuario - era o Script 7 manual):
-- nao ha como saber qual produto e o certo (a nota de entrada iria para o produto errado), entao TODOS os registros
-- do grupo saem. Um comando so: apaga e guarda a copia em migracao_auditoria.produto_fornecedor_removido (schema
-- separado, com a data) para conferir ou restaurar - sem tabela temporaria para criar e apagar a mao.
CREATE SCHEMA IF NOT EXISTS migracao_auditoria;
CREATE TABLE IF NOT EXISTS migracao_auditoria.produto_fornecedor_removido (
    removido_em timestamp NOT NULL DEFAULT now(),
    motivo      varchar(80),
    LIKE public.produto_fornecedor
);
WITH removidos AS (
    DELETE FROM produto_fornecedor pf
     USING (SELECT forcod, prfreffor
              FROM produto_fornecedor
             GROUP BY forcod, prfreffor
            HAVING COUNT(DISTINCT procod) > 1) d
     WHERE pf.forcod = d.forcod AND pf.prfreffor = d.prfreffor
    RETURNING pf.*
)
INSERT INTO migracao_auditoria.produto_fornecedor_removido
SELECT now(), 'mesma referencia do fornecedor em produtos diferentes', r.* FROM removidos r;

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
