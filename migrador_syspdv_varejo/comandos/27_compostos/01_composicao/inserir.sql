INSERT INTO composicao (comp_id, comp_procod, comp_quantidade, comp_baixa)
VALUES (nextval('sq_composicao'), %(comp_procod)s, %(comp_quantidade)s, %(comp_baixa)s)
