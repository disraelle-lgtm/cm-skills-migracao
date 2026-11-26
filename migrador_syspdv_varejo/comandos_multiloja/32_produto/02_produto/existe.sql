-- Produto ja no VarejoFacil (vinculo ou mesmo codigo de barras): so o indicador - a matriz nao e alterada.
WITH alvo AS (
    SELECT codigo_vf AS procod, 1 AS ordem FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text
    UNION ALL
    SELECT procod_vf, 2 FROM migracao_multiloja.produto_ean
     WHERE loj_codigo = {{loja_destino}} AND procod_origem = %(procod)s::text AND procod_vf IS NOT NULL
    ORDER BY 2, 1 LIMIT 1
)
SELECT EXISTS (SELECT 1 FROM migracao_multiloja.vinculo v WHERE v.loj_codigo = {{loja_destino}} AND v.tipo = 'produto' AND v.codigo_origem = %(procod)s::text) AS vinculado_loja
  FROM alvo
