SELECT 1 WHERE EXISTS (SELECT 1 FROM estoque_movimentacao m
 WHERE m.procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND m.loj_codigo = {{loja_destino}} AND m.loc_codigo = 1
   AND m.mov_historico = 'MIGRACAO'
 LIMIT 1)
   AND EXISTS (SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
