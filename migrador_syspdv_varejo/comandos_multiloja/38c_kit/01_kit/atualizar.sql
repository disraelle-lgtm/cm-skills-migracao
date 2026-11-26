UPDATE composicao SET comp_quantidade = %(comp_quantidade)s, comp_baixa = %(comp_baixa)s, comp_tipo = %(comp_tipo)s
 WHERE comp_procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(comp_procod)s::text)
