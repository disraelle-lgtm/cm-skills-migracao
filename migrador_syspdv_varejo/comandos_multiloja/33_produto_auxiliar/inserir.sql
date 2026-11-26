INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
VALUES (%(procodaux)s, (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text), %(proauxfat)s, %(proauxtipo)s, %(proauxcodigoean)s, %(proeantrib)s, %(proeanprinc)s)
