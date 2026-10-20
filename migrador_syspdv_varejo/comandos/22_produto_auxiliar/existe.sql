-- Pentaho: chave procodaux; todos os campos com Update = N (so insere).
-- A 2a parte trata como "ja existe" o EAN igual ao codigo de algum produto: a limpeza
-- (depois.sql) apagaria esse EAN de novo a cada rodada.
SELECT procodaux FROM produtoaux WHERE procodaux = %(procodaux)s
UNION ALL
SELECT %(procodaux)s
 WHERE %(codigo_numerico)s::bigint IN (SELECT procod FROM produto)
LIMIT 1
