SELECT 1 FROM migracao_multiloja.produto_ean WHERE loj_codigo = {{loja_destino}} AND procod_origem = %(procod)s::text LIMIT 1
