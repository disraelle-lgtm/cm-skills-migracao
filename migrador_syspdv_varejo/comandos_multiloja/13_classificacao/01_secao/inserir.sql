-- secao NOVO (outra descricao ou codigo livre): proximo codigo e vinculo novo = TRUE.
WITH novo AS (
    INSERT INTO secao (secid, seccod, secdes, sec_situacao_sped)
    SELECT nextval('sq_secao'), (CASE WHEN NOT EXISTS (SELECT 1 FROM secao WHERE seccod = %(seccod)s::int) THEN %(seccod)s::int ELSE (SELECT COALESCE(MAX(seccod), 0) + 1 FROM secao) END), %(secdes)s::varchar, %(sec_situacao_sped)s
    RETURNING seccod
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'secao', %(seccod)s::int::text, seccod, TRUE FROM novo
