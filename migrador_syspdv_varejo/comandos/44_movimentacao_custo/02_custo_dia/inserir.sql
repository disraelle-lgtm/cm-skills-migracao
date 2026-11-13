INSERT INTO custo_dia (cd_id, loj_codigo, procod, cd_data, cd_data_registro, cd_custo_fiscal, cd_custo_reposicao, cd_custo_medio)
VALUES (nextval('sq_mov_custo_dia'), %(loj_codigo)s, %(procod)s, %(data)s, %(data)s, %(custo_fiscal)s, %(custo_reposicao)s, %(custo_medio)s)
