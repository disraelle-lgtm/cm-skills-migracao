INSERT INTO produto_familia (codigo, codigo_produto, codigo_familia)
VALUES (nextval('sq_produto_familia'), %(codigo_produto)s, %(codigo_familia)s)
