-- So grava o vinculo com o secao que ja existia.
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text
    UNION ALL
    SELECT x.seccod, 2 FROM secao x
     WHERE  x.seccod = %(seccod)s::int AND UPPER(TRIM(x.secdes)) = UPPER(TRIM(%(secdes)s::varchar))
    ORDER BY 2, 1 LIMIT 1
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'secao', %(seccod)s::int::text, codigo, FALSE FROM alvo
ON CONFLICT (loj_codigo, tipo, codigo_origem) DO NOTHING
