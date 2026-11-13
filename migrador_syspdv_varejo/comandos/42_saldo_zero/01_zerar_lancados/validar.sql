-- So segue se a migracao ja lancou saldo para o produto (virada / rodar de novo). Sem movimento
-- MIGRACAO: "pulado" - ele recebe o movimento zero no lancamento em lote (02_lancar_zero).
SELECT 1 FROM estoque_movimentacao m
 WHERE m.procod = %(procod)s AND m.loj_codigo = %(loj_codigo)s AND m.loc_codigo = 1
   AND m.mov_historico = 'MIGRACAO'
 LIMIT 1
