UPDATE situacao_fiscal
   SET stf_descricao_reduzida = %(stf_descricao_reduzida)s, stf_descricao_completa = %(stf_descricao_completa)s
 WHERE stf_tributacao_rms = %(trbid)s
