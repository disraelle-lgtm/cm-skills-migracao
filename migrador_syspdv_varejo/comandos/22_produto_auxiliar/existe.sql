-- Pentaho: chave procodaux; todos os campos com Update = N (so insere).
-- A 2a parte trata como "ja existe" o EAN igual ao codigo de algum produto: a limpeza
-- (depois.sql) apagaria esse EAN de novo a cada rodada.
SELECT procodaux FROM produtoaux WHERE procodaux = %(procodaux)s
UNION ALL
SELECT %(procodaux)s
 WHERE EXISTS (SELECT 1 FROM produto WHERE procod = %(codigo_numerico)s::bigint)
LIMIT 1
-- Desempenho: EXISTS com procod = valor usa o indice da produto. Antes era
-- "valor IN (SELECT procod FROM produto)", que montava a lista de TODOS os produtos a cada EAN
-- (3,1 ms -> 0,5 ms por EAN num cadastro de 15 mil produtos; mais lento quanto maior o cadastro).
