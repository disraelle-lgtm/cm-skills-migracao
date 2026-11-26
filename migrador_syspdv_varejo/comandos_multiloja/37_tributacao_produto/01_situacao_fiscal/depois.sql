-- Pentaho: T-AtualizaSituacaoFiscalProduto - cada produto recebe a situacao fiscal da sua tributacao
UPDATE produto p
   SET stf_codigo = s.stf_codigo
     , stf_codigo_saida = s.stf_codigo
     , pro_stf_saida = FALSE
  FROM situacao_fiscal s
 WHERE s.stf_tributacao_rms = p.trbid;
SET session_replication_role = DEFAULT
