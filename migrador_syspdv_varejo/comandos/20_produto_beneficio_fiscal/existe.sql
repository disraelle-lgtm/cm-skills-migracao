-- Pentaho: chave (procod, loj_codigo); o codigo de beneficio tem Update = Y
SELECT cpl_cbenef FROM cbenef_produto_loja WHERE procod = %(procod)s AND loj_codigo = %(loj_codigo)s
