-- Pentaho: chave (cc_comp_id, cc_procod); todos os campos com Update = N (so insere)
SELECT cc_id FROM componentes_composicao WHERE cc_comp_id = (SELECT comp_id FROM composicao WHERE comp_procod = %(procod)s ORDER BY comp_id LIMIT 1) AND cc_procod = %(cc_procod)s
