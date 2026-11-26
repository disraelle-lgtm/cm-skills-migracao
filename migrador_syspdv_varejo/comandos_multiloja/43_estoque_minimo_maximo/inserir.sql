INSERT INTO produto_estoque (peq_id, procod, loj_codigo, peq_minimo, peq_maximo)
VALUES (nextval('sq_produto_estoque'), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text), {{loja_destino}}, %(peq_minimo)s, %(peq_maximo)s)
