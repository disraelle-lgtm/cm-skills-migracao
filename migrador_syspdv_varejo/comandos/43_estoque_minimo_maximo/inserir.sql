INSERT INTO produto_estoque (peq_id, procod, loj_codigo, peq_minimo, peq_maximo)
VALUES (nextval('sq_produto_estoque'), %(procod)s, %(loj_codigo)s, %(peq_minimo)s, %(peq_maximo)s)
