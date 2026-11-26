-- GARANTIA: roda sempre no fim da execucao, mesmo se a migracao parar no meio com erro.
-- O DISABLE TRIGGER fica gravado na tabela: sem isto, um erro no meio deixaria a tabela produto
-- da base do cliente com as triggers desligadas.
ALTER TABLE produto ENABLE TRIGGER ALL
