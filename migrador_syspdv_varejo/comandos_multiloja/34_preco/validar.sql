-- So para os produtos migrados nesta loja (novos e ja existentes).
SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text
