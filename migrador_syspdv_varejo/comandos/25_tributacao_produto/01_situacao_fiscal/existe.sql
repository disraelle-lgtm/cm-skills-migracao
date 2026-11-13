-- Pentaho: chave stf_tributacao_rms = TRBID; descricoes com Update = Y
SELECT stf_descricao_reduzida, stf_descricao_completa
  FROM situacao_fiscal
 WHERE stf_tributacao_rms = %(trbid)s
