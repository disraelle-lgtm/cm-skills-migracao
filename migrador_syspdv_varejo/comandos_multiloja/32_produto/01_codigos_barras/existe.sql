SELECT 1 AS ja_lido FROM migracao_multiloja.produto_ean WHERE loj_codigo = {{loja_destino}} AND procod_origem = %(procod)s::text AND ean = %(ean)s::varchar
