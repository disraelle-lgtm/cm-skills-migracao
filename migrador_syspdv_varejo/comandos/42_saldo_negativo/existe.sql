-- Compara o saldo do SysPDV com a soma dos movimentos MIGRACAO deste produto (loja + local 1).
-- Igual e com UM movimento so = sem alteracao (nada e apagado nem inserido). Diferente, ou com
-- mais de um movimento MIGRACAO (ex.: os do "Zerar" do Pentaho) = atualizar.sql apaga os movimentos
-- MIGRACAO DESTE produto e lanca o saldo correto num movimento so. Sem movimento = inserir.sql.
-- mais de um movimento devolve NULL: conta como diferente e o historico e consolidado
SELECT CASE WHEN COUNT(*) = 1 THEN SUM(m.mov_quantidade) END AS mov_quantidade
  FROM estoque_movimentacao m
 WHERE m.procod = %(procod)s AND m.loj_codigo = %(loj_codigo)s AND m.loc_codigo = 1
   AND m.mov_historico = 'MIGRACAO'
HAVING COUNT(*) > 0
