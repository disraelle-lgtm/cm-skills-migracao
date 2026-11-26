-- Reconhecimento EM BLOCO (uma consulta so, rapida): para cada produto da loja adicional, o produto do VarejoFacil
-- que tem algum dos mesmos codigos de barras (produtoaux) ou o mesmo codigo quando e EAN (procod > 999999).
ANALYZE migracao_multiloja.produto_ean;
UPDATE migracao_multiloja.produto_ean SET procod_vf = NULL WHERE loj_codigo = {{loja_destino}};
WITH vf AS (
    SELECT LTRIM(a.procodaux, '0') AS ean, a.procod FROM produtoaux a WHERE a.procodaux ~ '^[0-9]+$'
    UNION ALL
    SELECT p.procod::text, p.procod FROM produto p WHERE p.procod > 999999
), m AS (
    SELECT DISTINCT ON (e.procod_origem) e.procod_origem, vf.procod
      FROM migracao_multiloja.produto_ean e JOIN vf ON vf.ean = e.ean
     WHERE e.loj_codigo = {{loja_destino}}
     ORDER BY e.procod_origem, vf.procod
)
UPDATE migracao_multiloja.produto_ean e SET procod_vf = m.procod
  FROM m WHERE e.loj_codigo = {{loja_destino}} AND e.procod_origem = m.procod_origem
