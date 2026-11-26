SELECT COALESCE(SUM(m.mov_quantidade), 0) AS mov_quantidade
  FROM estoque_movimentacao m
 WHERE m.procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND m.loj_codigo = {{loja_destino}} AND m.loc_codigo = 1
HAVING COUNT(*) > 0
