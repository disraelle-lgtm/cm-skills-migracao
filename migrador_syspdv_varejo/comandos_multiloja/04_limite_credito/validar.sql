-- So os clientes CRIADOS por esta loja recebem o limite; o cliente que ja existia na matriz mantem o limite dela.
SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text AND novo
