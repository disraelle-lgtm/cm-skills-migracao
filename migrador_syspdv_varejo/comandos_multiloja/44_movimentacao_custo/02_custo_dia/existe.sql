SELECT cd_custo_fiscal AS custo_fiscal, cd_custo_reposicao AS custo_reposicao, cd_custo_medio AS custo_medio
  FROM custo_dia WHERE loj_codigo = {{loja_destino}} AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
 LIMIT 1
