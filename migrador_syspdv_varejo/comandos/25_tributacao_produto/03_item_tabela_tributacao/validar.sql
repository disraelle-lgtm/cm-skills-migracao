SELECT 1
  FROM tabela_tributacao t
  JOIN situacao_fiscal s ON (s.stf_codigo = t.stf_codigo)
 WHERE s.stf_tributacao_rms = %(trbid)s::varchar
