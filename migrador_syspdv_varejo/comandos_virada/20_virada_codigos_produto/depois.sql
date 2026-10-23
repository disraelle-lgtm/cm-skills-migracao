-- So roda de verdade se a virada tem arquivo de codigos de produtos (tabela temporaria mapa_codigos).
DO $$
DECLARE
  matriz integer;
BEGIN
  IF to_regclass('pg_temp.mapa_codigos') IS NULL
     OR NOT EXISTS (SELECT 1 FROM mapa_codigos WHERE tipo = 'produto') THEN
    RAISE NOTICE 'Virada sem arquivo de codigos de produtos: nada a fazer.';
    RETURN;
  END IF;
  SELECT loj_codigo INTO matriz FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1;

  -- 1) Produto novo da virada cujo codigo do SysPDV era EAN (>= 999999) e ganhou codigo novo:
  --    o EAN antigo vira codigo de barras do produto (mesma regra do ajuste de codigos do kit),
  --    senao o PDV deixa de ler o produto pelo codigo de barras.
  INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
  SELECT LPAD(CAST(m.codigo_antigo AS TEXT), 14, '0'), m.codigo_novo, 1, 'EAN',
         CAST(SUBSTR(CAST(m.codigo_antigo AS TEXT), 1, LENGTH(CAST(m.codigo_antigo AS TEXT)) - 1) AS BIGINT),
         true, true
    FROM mapa_codigos m
    JOIN produto p ON p.procod = m.codigo_novo
   WHERE m.tipo = 'produto'
     AND m.novo_na_virada
     AND m.codigo_antigo <> m.codigo_novo
     AND m.codigo_antigo >= 999999
     AND NOT EXISTS (SELECT 1 FROM produtoaux a WHERE a.procodaux = LPAD(CAST(m.codigo_antigo AS TEXT), 14, '0'));

  -- 2) Alteracao de produto do SPED - MESMO padrao do ajuste de codigos do kit (ajusta_produto.sql):
  --    MANTEM as alteracoes anteriores (nao apaga a tabela, como fazia o "Insert SPED" do Pentaho:
  --    isso perdia a data de exportacao das trocas da primeira migracao) e insere so as trocas que
  --    ainda nao estao la.
  INSERT INTO alteracao_produto_sped (aps_codigo, procod, aps_data_inicial, aps_data_final,
                                      aps_descricao_anterior, aps_procod_anterior, loj_codigo)
  SELECT NEXTVAL('sq_alt_produto_sped'), p.procod, p.prodatcadinc, p.prodatcadalt, '', m.codigo_antigo, matriz
    FROM mapa_codigos m
    JOIN produto p ON p.procod = m.codigo_novo
   WHERE m.tipo = 'produto'
     AND m.codigo_antigo <> m.codigo_novo
     AND NOT EXISTS (SELECT 1 FROM alteracao_produto_sped a
                      WHERE a.procod = m.codigo_novo AND a.aps_procod_anterior = m.codigo_antigo)
   ORDER BY p.procod;

  -- 3) Data de exportacao = hoje, gravada DEPOIS do INSERT (como no kit: dentro do INSERT ela nao
  --    ficava gravada) e so nas linhas desta virada que ainda estao sem data - as anteriores ficam
  --    como estao.
  UPDATE alteracao_produto_sped a
     SET aps_data_exportacao = CURRENT_DATE
    FROM mapa_codigos m
   WHERE m.tipo = 'produto'
     AND m.codigo_antigo <> m.codigo_novo
     AND a.procod = m.codigo_novo
     AND a.aps_procod_anterior = m.codigo_antigo
     AND a.aps_data_exportacao IS NULL;
END $$
