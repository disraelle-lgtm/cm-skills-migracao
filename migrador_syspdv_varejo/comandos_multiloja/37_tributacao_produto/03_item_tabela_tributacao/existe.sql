-- Procura pela CHAVE UNICA do VarejoFacil: (tabela tributaria, UF, classificacao da pessoa).
-- * achou com o MESMO codigo de tributacao (trbid): compara as colunas e atualiza o que mudou (como antes);
-- * achou com OUTRO trbid (ex.: virada, item ja cadastrado): devolve os proprios valores do SysPDV -> "sem
--   alteracao" - passa, sem sobrescrever e sem tentar incluir de novo (antes: erro de chave duplicada).
-- Os dois lados do CASE em texto: o motor compara sem depender do tipo (0 = '0' = 0.00). Cada parametro tem
-- SEMPRE o mesmo tipo (::text): o motor PREPARA o comando e o PostgreSQL recusa tipos diferentes para o mesmo
-- parametro ("inconsistent types deduced", erro da versao 2026.11.28).
SELECT CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_tributacao_nf::text ELSE %(itt_tributacao_nf)s::text END AS itt_tributacao_nf
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_aliquota::text ELSE %(itt_aliquota)s::text END AS itt_aliquota
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_outros_nf::text ELSE %(itt_outros_nf)s::text END AS itt_outros_nf
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_isento_nf::text ELSE %(itt_isento_nf)s::text END AS itt_isento_nf
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_cst::text ELSE %(itt_cst)s::text END AS itt_cst
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_classificacao_pessoa::text ELSE %(itt_classificacao_pessoa)s::text END AS itt_classificacao_pessoa
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_agregado::text ELSE %(itt_agregado)s::text END AS itt_agregado
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_carga_liquida::text ELSE %(itt_carga_liquida)s::text END AS itt_carga_liquida
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_aliquota_interna::text ELSE %(itt_aliquota_interna)s::text END AS itt_aliquota_interna
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_tributado_icms::text ELSE %(itt_tributado_icms)s::text END AS itt_tributado_icms
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_fecop::text ELSE %(itt_fecop)s::text END AS itt_fecop
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_cfop::text ELSE %(itt_cfop)s::text END AS itt_cfop
     , CASE WHEN i.trbid::text = %(trbid)s::text THEN i.itt_uf::text ELSE %(itt_uf)s::text END AS itt_uf
  FROM item_tabela_tributacao i
  JOIN tabela_tributacao t ON (t.tbt_id = i.tbt_id)
  JOIN situacao_fiscal s ON (s.stf_codigo = t.stf_codigo)
 WHERE s.stf_tributacao_rms::text = %(trbid)s::text
   AND i.itt_uf::text = %(itt_uf)s::text
   AND i.itt_classificacao_pessoa::text = %(itt_classificacao_pessoa)s::text
 ORDER BY (i.trbid::text = %(trbid)s::text) DESC
 LIMIT 1
