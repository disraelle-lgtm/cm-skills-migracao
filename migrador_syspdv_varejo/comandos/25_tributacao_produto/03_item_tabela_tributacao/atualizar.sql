UPDATE item_tabela_tributacao i
   SET itt_tributacao_nf = %(itt_tributacao_nf)s
     , itt_aliquota = %(itt_aliquota)s
     , itt_outros_nf = %(itt_outros_nf)s
     , itt_isento_nf = %(itt_isento_nf)s
     , itt_cst = %(itt_cst)s
     , itt_agregado = %(itt_agregado)s
     , itt_carga_liquida = %(itt_carga_liquida)s
     , itt_aliquota_interna = %(itt_aliquota_interna)s
     , itt_tributado_icms = %(itt_tributado_icms)s
     , itt_fecop = %(itt_fecop)s
     , itt_cfop = %(itt_cfop)s
     , itt_uf = %(itt_uf)s
  FROM tabela_tributacao t
  JOIN situacao_fiscal s ON (s.stf_codigo = t.stf_codigo)
 WHERE i.tbt_id = t.tbt_id
   AND s.stf_tributacao_rms = %(trbid)s::varchar
   AND i.trbid = %(trbid)s::varchar
   AND i.itt_classificacao_pessoa = %(itt_classificacao_pessoa)s::varchar
