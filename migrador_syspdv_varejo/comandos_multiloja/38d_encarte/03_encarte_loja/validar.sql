SELECT 1 WHERE EXISTS (SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'encarte' AND codigo_origem = %(enccod)s::text)
