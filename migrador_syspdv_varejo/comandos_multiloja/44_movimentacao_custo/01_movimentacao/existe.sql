SELECT moc_id FROM movimentacao_de_custo
 WHERE loj_codigo = {{loja_destino}} AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND moc_tipo_movimentacao = 'AJUSTE_CUSTO'
 LIMIT 1
