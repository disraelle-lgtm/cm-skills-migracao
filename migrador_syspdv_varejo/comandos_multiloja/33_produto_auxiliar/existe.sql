SELECT procodaux FROM produtoaux WHERE procodaux = %(procodaux)s
UNION ALL
SELECT %(procodaux)s
 WHERE EXISTS (SELECT 1 FROM produto WHERE procod = %(codigo_numerico)s::bigint)
LIMIT 1
