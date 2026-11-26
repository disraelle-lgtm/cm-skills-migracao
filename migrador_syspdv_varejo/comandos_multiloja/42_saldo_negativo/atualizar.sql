INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, mov_quantidade, mov_historico, eta_codigo,
                                  loc_codigo, mov_data, fun_codigo, mov_tipo, mov_data_registro)
SELECT nextval('sq_movimentacao_estoque'), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text), {{loja_destino}},
       %(mov_quantidade)s::numeric - COALESCE(SUM(m.mov_quantidade), 0), 'MIGRACAO', 9002,
       1, %(mov_data)s::date, 1, 'AJUSTE', %(mov_data)s::date
  FROM estoque_movimentacao m
 WHERE m.procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND m.loj_codigo = {{loja_destino}} AND m.loc_codigo = 1
HAVING %(mov_quantidade)s::numeric - COALESCE(SUM(m.mov_quantidade), 0) <> 0
