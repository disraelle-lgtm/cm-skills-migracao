-- Pentaho: ajuste 9002, historico MIGRACAO, local 1, funcionario 1.
INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, mov_quantidade, mov_historico, eta_codigo,
                                  loc_codigo, mov_data, fun_codigo, mov_tipo, mov_data_registro)
VALUES (nextval('sq_movimentacao_estoque'), %(procod)s, %(loj_codigo)s, %(mov_quantidade)s, 'MIGRACAO', 9002,
       1, %(mov_data)s, 1, 'AJUSTE', %(mov_data)s)
