INSERT INTO impostos_federais_produto (impfpid, impfedsim, procod)
VALUES (nextval('sq_impostos_federais_produto'), %(impfedsim)s, (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text))
