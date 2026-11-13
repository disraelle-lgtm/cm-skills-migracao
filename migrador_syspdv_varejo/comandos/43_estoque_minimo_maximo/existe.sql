-- Pentaho: chave (procod, loj_codigo); todos com Update = N (so insere)
SELECT peq_id FROM produto_estoque WHERE procod = %(procod)s AND loj_codigo = %(loj_codigo)s
