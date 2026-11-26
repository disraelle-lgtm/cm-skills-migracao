-- Encarte da loja adicional: mantem o codigo se estiver livre (o codigo e unico no banco), senao o proximo.
WITH novo AS (
INSERT INTO encarte (enccod, loj_codigo, encdes, encdatini, encdatfim, encstatus, enc_atualiza_preco_1, enc_atualiza_preco_2, enc_atualiza_preco_3, enc_produto_fora_linha)
VALUES ((CASE WHEN NOT EXISTS (SELECT 1 FROM encarte WHERE enccod = %(enccod)s::int) THEN %(enccod)s::int ELSE (SELECT COALESCE(MAX(enccod), 0) + 1 FROM encarte) END), {{loja_destino}}, %(encdes)s, %(encdatini)s, %(encdatfim)s, %(encstatus)s, %(enc_atualiza_preco_1)s, %(enc_atualiza_preco_2)s, %(enc_atualiza_preco_3)s, %(enc_produto_fora_linha)s)
    RETURNING enccod
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'encarte', %(enccod)s::int::text, enccod, TRUE FROM novo
