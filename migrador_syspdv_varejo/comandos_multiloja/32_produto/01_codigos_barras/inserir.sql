INSERT INTO migracao_multiloja.produto_ean (loj_codigo, procod_origem, ean) VALUES ({{loja_destino}}, %(procod)s::text, %(ean)s::varchar) ON CONFLICT DO NOTHING
