-- Pentaho: chave (loj_codigo, procod); todos com Update = N (so insere)
SELECT ac_id FROM auditoria_custo WHERE loj_codigo = %(loj_codigo)s AND procod = %(procod)s
