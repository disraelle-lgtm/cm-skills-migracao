-- Um item para cada tabela tributaria desta tributacao (normalmente uma: a da UF da loja matriz)
INSERT INTO item_tabela_tributacao (itt_id, tbt_id, trbid, itt_tributacao_nf, itt_aliquota, itt_outros_nf, itt_isento_nf, itt_cst, itt_classificacao_pessoa, itt_agregado, itt_carga_liquida, itt_aliquota_interna, itt_tributado_icms, itt_fecop, itt_cfop, itt_uf)
SELECT nextval('sq_item_tabela_tributacao'), t.tbt_id, %(trbid)s::varchar, %(itt_tributacao_nf)s, %(itt_aliquota)s, %(itt_outros_nf)s, %(itt_isento_nf)s, %(itt_cst)s, %(itt_classificacao_pessoa)s::varchar, %(itt_agregado)s, %(itt_carga_liquida)s, %(itt_aliquota_interna)s, %(itt_tributado_icms)s, %(itt_fecop)s, %(itt_cfop)s, %(itt_uf)s
  FROM tabela_tributacao t
  JOIN situacao_fiscal s ON (s.stf_codigo = t.stf_codigo)
 WHERE s.stf_tributacao_rms = %(trbid)s::varchar
   AND NOT EXISTS (SELECT 1 FROM item_tabela_tributacao i
                    WHERE i.tbt_id = t.tbt_id AND i.trbid = %(trbid)s::varchar
                      AND i.itt_classificacao_pessoa = %(itt_classificacao_pessoa)s::varchar)
