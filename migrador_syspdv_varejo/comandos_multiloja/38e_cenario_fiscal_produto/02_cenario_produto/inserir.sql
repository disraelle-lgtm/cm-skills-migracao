INSERT INTO cenario_fiscal_produto_produto (cfp_codigo, procod, seccod, secdes, grpcod, grpdes, sgpcod, sgpdes)
VALUES (%(cfp_codigo)s, (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text), %(seccod)s, %(secdes)s, %(grpcod)s, %(grpdes)s, %(sgpcod)s, %(sgpdes)s)
