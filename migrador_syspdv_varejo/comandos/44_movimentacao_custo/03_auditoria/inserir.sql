INSERT INTO auditoria_custo (ac_id, loj_codigo, procod, ac_custo_reposicao, ac_custo_fiscal, ac_origem, ac_data_registro, fun_codigo)
VALUES (nextval('sq_auditoria_custo'), %(loj_codigo)s, %(procod)s, %(ac_custo_reposicao)s, %(ac_custo_fiscal)s, 'INICIAL', %(data)s, 1)
