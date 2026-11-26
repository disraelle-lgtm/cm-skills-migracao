-- secao: pelo vinculo ou mesmo codigo E mesma descricao -> so o indicador (a matriz nao e alterada).
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text
    UNION ALL
    SELECT x.seccod, 2 FROM secao x
     WHERE  x.seccod = %(seccod)s::int AND UPPER(TRIM(x.secdes)) = UPPER(TRIM(%(secdes)s::varchar))
    ORDER BY 2, 1 LIMIT 1
)
SELECT EXISTS (SELECT 1 FROM migracao_multiloja.vinculo v WHERE v.loj_codigo = {{loja_destino}} AND v.tipo = 'secao' AND v.codigo_origem = %(seccod)s::int::text) AS vinculado_loja
  FROM alvo
