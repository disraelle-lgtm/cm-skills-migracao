-- Saldo ATUAL do produto no VarejoFacil: soma de TODOS os movimentos (migracao, vendas, inventarios...) na
-- loja/local 1 - a mesma conta do recalculo do estoque_resumo. Igual ao do SysPDV = "sem alteracao".
SELECT COALESCE(SUM(m.mov_quantidade), 0) AS mov_quantidade
  FROM estoque_movimentacao m
 WHERE m.procod = %(procod)s AND m.loj_codigo = %(loj_codigo)s AND m.loc_codigo = 1
HAVING COUNT(*) > 0
