-- No Pentaho so a descricao e atualizada (os demais campos tem Update = N)
SELECT loc_descricao FROM local_estoque WHERE loc_codigo = %(loc_codigo)s
