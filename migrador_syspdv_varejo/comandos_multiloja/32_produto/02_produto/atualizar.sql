-- So grava o vinculo com o produto que ja existia.
WITH alvo AS (
    SELECT codigo_vf AS procod, 1 AS ordem FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text
    UNION ALL
    SELECT procod_vf, 2 FROM migracao_multiloja.produto_ean
     WHERE loj_codigo = {{loja_destino}} AND procod_origem = %(procod)s::text AND procod_vf IS NOT NULL
    ORDER BY 2, 1 LIMIT 1
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'produto', %(procod)s::text, procod, FALSE FROM alvo
ON CONFLICT (loj_codigo, tipo, codigo_origem) DO NOTHING
