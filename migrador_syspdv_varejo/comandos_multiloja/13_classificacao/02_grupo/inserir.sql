-- grupo NOVO (outra descricao ou codigo livre): proximo codigo e vinculo novo = TRUE.
WITH novo AS (
    INSERT INTO grupo_produto (grpid, seccod, grpcod, grpdes)
    SELECT nextval('sq_grupo_produto'), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text), (CASE WHEN NOT EXISTS (SELECT 1 FROM grupo_produto WHERE seccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text) AND grpcod = %(grpcod)s::int) THEN %(grpcod)s::int ELSE (SELECT COALESCE(MAX(grpcod), 0) + 1 FROM grupo_produto WHERE seccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'secao' AND codigo_origem = %(seccod)s::int::text)) END), %(grpdes)s::varchar
    RETURNING grpcod
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'grupo', %(seccod)s::int::text || '|' || %(grpcod)s::int::text, grpcod, TRUE FROM novo
