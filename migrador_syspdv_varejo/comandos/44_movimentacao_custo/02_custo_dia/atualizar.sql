UPDATE custo_dia
   SET cd_data = %(data)s, cd_data_registro = %(data)s, cd_custo_fiscal = %(custo_fiscal)s,
       cd_custo_reposicao = %(custo_reposicao)s, cd_custo_medio = %(custo_medio)s
 WHERE loj_codigo = %(loj_codigo)s AND procod = %(procod)s
