UPDATE custo_dia
   SET cd_data = %(data)s, cd_data_registro = %(data)s, cd_custo_fiscal = %(custo_fiscal)s,
       cd_custo_reposicao = %(custo_reposicao)s, cd_custo_medio = %(custo_medio)s
 WHERE loj_codigo = {{loja_destino}} AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
