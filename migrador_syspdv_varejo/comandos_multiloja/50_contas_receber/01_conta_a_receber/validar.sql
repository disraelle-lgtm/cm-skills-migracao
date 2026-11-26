SELECT 1 WHERE EXISTS (SELECT 1 FROM pessoa_cliente WHERE cli_codigo = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text))
   AND EXISTS (SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text)
