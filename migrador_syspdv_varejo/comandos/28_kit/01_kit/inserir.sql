INSERT INTO composicao (comp_id, comp_procod, comp_quantidade, comp_baixa, comp_tipo)
VALUES (nextval('sq_composicao'), %(comp_procod)s, %(comp_quantidade)s, %(comp_baixa)s, %(comp_tipo)s)
