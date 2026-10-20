-- No Pentaho a chave era "itt_id IS NULL" (sempre inseria: cada execucao DUPLICAVA os itens).
-- Aqui: um item por tabela tributaria da tributacao + classificacao.
SELECT i.itt_tributacao_nf, i.itt_aliquota, i.itt_outros_nf, i.itt_isento_nf, i.itt_cst, i.itt_classificacao_pessoa, i.itt_agregado, i.itt_carga_liquida, i.itt_aliquota_interna, i.itt_tributado_icms, i.itt_fecop, i.itt_cfop, i.itt_uf
  FROM item_tabela_tributacao i
  JOIN tabela_tributacao t ON (t.tbt_id = i.tbt_id)
  JOIN situacao_fiscal s ON (s.stf_codigo = t.stf_codigo)
 WHERE s.stf_tributacao_rms = %(trbid)s::varchar
   AND i.trbid = %(trbid)s::varchar
   AND i.itt_classificacao_pessoa = %(itt_classificacao_pessoa)s::varchar
 LIMIT 1
