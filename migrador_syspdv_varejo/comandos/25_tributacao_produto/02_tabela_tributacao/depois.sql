-- Pentaho: T-ItemTabelaTributaria (tabela_tributacao). Uma tabela de SAIDA por situacao fiscal,
-- para o regime (ret_codigo) e a UF da loja matriz, vigencia a partir de 01/01/2016.
-- No Pentaho a UF e a loja vinham do PROPRIO (PRPUF / PRPCOD) - sao a UF e o codigo da loja
-- matriz gravados pelo item "Dados da Loja".
SET session_replication_role = replica;

INSERT INTO tabela_tributacao (tbt_id, ret_codigo, stf_codigo, tbt_uf, tbt_inicio_vingencia, fig_codigo, tbt_tipo_operacao)
SELECT nextval('sq_tabela_tributacao'), COALESCE(l.ret_codigo, 1), sf.stf_codigo, TRIM(pe.pes_uf),
       TIMESTAMP '2016-01-01 00:00:00', l.fig_codigo, 'SAIDA'
  FROM pessoa_loja l
  JOIN pessoa pe ON (pe.pes_codigo = l.pes_codigo)
 CROSS JOIN situacao_fiscal sf
 WHERE l.loj_matriz = 'S'
   AND NOT EXISTS (SELECT 1 FROM tabela_tributacao t
                    WHERE t.ret_codigo = COALESCE(l.ret_codigo, 1) AND t.stf_codigo = sf.stf_codigo
                      AND t.tbt_uf = TRIM(pe.pes_uf) AND t.tbt_tipo_operacao = 'SAIDA');

-- Update = Y no Pentaho: inicio de vigencia e figura fiscal
UPDATE tabela_tributacao t
   SET tbt_inicio_vingencia = TIMESTAMP '2016-01-01 00:00:00', fig_codigo = l.fig_codigo
  FROM pessoa_loja l
  JOIN pessoa pe ON (pe.pes_codigo = l.pes_codigo)
 WHERE l.loj_matriz = 'S'
   AND t.ret_codigo = COALESCE(l.ret_codigo, 1) AND t.tbt_uf = TRIM(pe.pes_uf) AND t.tbt_tipo_operacao = 'SAIDA';

SET session_replication_role = DEFAULT
