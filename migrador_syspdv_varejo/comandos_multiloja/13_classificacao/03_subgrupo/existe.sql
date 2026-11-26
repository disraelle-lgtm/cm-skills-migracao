-- subgrupo: pelo vinculo ou mesmo codigo E mesma descricao -> so o indicador (a matriz nao e alterada).
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'subgrupo' AND codigo_origem = %(seccod)s::int::text || '|' || %(grpcod)s::int::text || '|' || %(sgpcod)s::int::text
    UNION ALL
    SELECT x.sgpcod, 2 FROM subgrupo_produto x
     WHERE x.seccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text) AND x.grpcod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'grupo' AND codigo_origem = %(seccod)s::int::text || '|' || %(grpcod)s::int::text) AND x.sgpcod = %(sgpcod)s::int AND UPPER(TRIM(x.sgpdes)) = UPPER(TRIM(%(sgpdes)s::varchar))
    ORDER BY 2, 1 LIMIT 1
)
SELECT EXISTS (SELECT 1 FROM migracao_multiloja.vinculo v WHERE v.loj_codigo = {{loja_destino}} AND v.tipo = 'subgrupo' AND v.codigo_origem = %(seccod)s::int::text || '|' || %(grpcod)s::int::text || '|' || %(sgpcod)s::int::text) AS vinculado_loja
  FROM alvo
