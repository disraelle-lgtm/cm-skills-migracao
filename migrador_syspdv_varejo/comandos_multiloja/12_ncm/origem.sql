-- Pentaho: FB - PRODUTO_NCM (T-TabelasBasicasNCM-Validacao_inicial).
-- DISTINCT: o Pentaho levava todos os produtos para uma tabela temporaria e depois
-- agrupava por NCM; aqui ja trazemos cada NCM uma vez so (mesmo resultado).
-- Segue a opcao "Incluir produtos fora de linha" do Produto: nao cria NCM de produto
-- fora de linha que nao sera migrado.
SELECT DISTINCT PRONCM
  FROM PRODUTO
 WHERE PRODES IS NOT NULL
   AND PROCOD <> '00000000000000'
   AND (COALESCE(PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
