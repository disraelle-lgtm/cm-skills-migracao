-- Desliga as triggers da tabela produto durante a migracao dos produtos.
-- Religadas nos "Ajustes finais de Produto" (29_ajustes_produto/depois.sql).
ALTER TABLE produto DISABLE TRIGGER ALL
