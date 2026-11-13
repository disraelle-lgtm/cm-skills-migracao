-- Saldo diferente do SysPDV: lanca UM movimento novo (mov_id novo, historico MIGRACAO) com a DIFERENCA, para o
-- saldo ficar igual ao do SysPDV. NADA e apagado: antes apagava o movimento MIGRACAO e lancava de novo, e o banco
-- recusava quando o movimento ja era usado num inventario ("mov_id ... ainda e usado na tabela item_inventario").
-- Cada parametro com um tipo so (o comando e preparado a partir da 6a linha).
INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, mov_quantidade, mov_historico, eta_codigo,
                                  loc_codigo, mov_data, fun_codigo, mov_tipo, mov_data_registro)
SELECT nextval('sq_movimentacao_estoque'), %(procod)s::bigint, %(loj_codigo)s::bigint,
       %(mov_quantidade)s::numeric - COALESCE(SUM(m.mov_quantidade), 0), 'MIGRACAO', 9002,
       1, %(mov_data)s::date, 1, 'AJUSTE', %(mov_data)s::date
  FROM estoque_movimentacao m
 WHERE m.procod = %(procod)s::bigint AND m.loj_codigo = %(loj_codigo)s::bigint AND m.loc_codigo = 1
HAVING %(mov_quantidade)s::numeric - COALESCE(SUM(m.mov_quantidade), 0) <> 0
