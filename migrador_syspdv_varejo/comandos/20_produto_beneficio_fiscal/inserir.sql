INSERT INTO cbenef_produto_loja (cpl_id, procod, loj_codigo, cpl_cbenef)
VALUES (nextval('sq_cbenef_produto_loja'), %(procod)s, %(loj_codigo)s, %(cpl_cbenef)s)
