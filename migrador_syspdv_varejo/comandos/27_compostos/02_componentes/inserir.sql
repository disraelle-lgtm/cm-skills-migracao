INSERT INTO componentes_composicao (cc_id, cc_comp_id, cc_procod, cc_quantidade, cc_preco1, cc_preco2, cc_preco3)
VALUES (nextval('sq_componentes_composicao'), (SELECT comp_id FROM composicao WHERE comp_procod = %(procod)s ORDER BY comp_id LIMIT 1), %(cc_procod)s, %(cc_quantidade)s,
        %(cc_preco1)s, %(cc_preco2)s, %(cc_preco3)s)
