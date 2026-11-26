-- So grava o vinculo com o grupo que ja existia.
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'grupo' AND codigo_origem = %(seccod)s::int::text || '|' || %(grpcod)s::int::text
    UNION ALL
    SELECT x.grpcod, 2 FROM grupo_produto x
     WHERE x.seccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text) AND x.grpcod = %(grpcod)s::int AND UPPER(TRIM(x.grpdes)) = UPPER(TRIM(%(grpdes)s::varchar))
    ORDER BY 2, 1 LIMIT 1
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'grupo', %(seccod)s::int::text || '|' || %(grpcod)s::int::text, codigo, FALSE FROM alvo
ON CONFLICT (loj_codigo, tipo, codigo_origem) DO NOTHING
