INSERT INTO composicao (comp_id, comp_procod, comp_quantidade, comp_baixa, comp_tipo)
VALUES (nextval('sq_composicao'), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(comp_procod)s::text), %(comp_quantidade)s, %(comp_baixa)s, %(comp_tipo)s)
