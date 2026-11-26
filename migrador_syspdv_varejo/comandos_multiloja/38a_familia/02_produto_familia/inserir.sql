INSERT INTO produto_familia (codigo, codigo_produto, codigo_familia)
VALUES (nextval('sq_produto_familia'), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(codigo_produto)s::text), %(codigo_familia)s)
