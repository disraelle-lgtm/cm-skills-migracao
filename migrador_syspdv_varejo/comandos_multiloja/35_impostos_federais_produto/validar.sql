-- So para os produtos CRIADOS por esta loja.
SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text AND novo
