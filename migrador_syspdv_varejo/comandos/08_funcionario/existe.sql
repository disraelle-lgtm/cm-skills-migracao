-- Procura o funcionario pelo CODIGO e, se nao achar, pelo CPF (no VarejoFacil o CPF da pessoa e unico):
-- * mesmo codigo: compara as colunas e atualiza o que mudou (como antes);
-- * ja cadastrado com o MESMO CPF e outro codigo (ex.: virada): devolve os proprios valores do SysPDV -> "sem
--   alteracao" - passa, sem duplicar e sem mexer (antes: erro de CPF/pes_num_documento ja existente).
-- Os dois lados do CASE em texto (o motor compara sem depender do tipo); os campos true/false ficam booleanos.
SELECT CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_cargo_syspdv::text ELSE %(fun_cargo_syspdv)s::text END AS fun_cargo_syspdv
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_limite_desconto::text ELSE %(fun_limite_desconto)s::text END AS fun_limite_desconto
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_comissao1::text ELSE %(fun_comissao1)s::text END AS fun_comissao1
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_comissao2::text ELSE %(fun_comissao2)s::text END AS fun_comissao2
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_comissao3::text ELSE %(fun_comissao3)s::text END AS fun_comissao3
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_tipo_preco_padrao::text ELSE %(fun_tipo_preco_padrao)s::text END AS fun_tipo_preco_padrao
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_comissao_por_metas::text ELSE %(fun_comissao_por_metas)s::text END AS fun_comissao_por_metas
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_inativo::text ELSE %(fun_inativo)s::text END AS fun_inativo
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pf.fun_ace::text ELSE %(fun_ace)s::text END AS fun_ace
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pfl.pfl_ativo::text ELSE %(pfl_ativo)s::text END AS pfl_ativo
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN pfl.pfl_principal ELSE TRUE END AS pfl_principal
     , CASE WHEN pf.fun_codigo = %(funcod)s THEN (pfl.loj_codigo IS NOT DISTINCT FROM (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)) ELSE TRUE END AS loja_matriz_ok
  FROM pessoa_funcionario pf
  JOIN pessoa p ON (p.pes_codigo = pf.pes_codigo)
  LEFT JOIN pessoa_funcionario_loja pfl ON (pfl.fun_codigo = pf.fun_codigo)
 WHERE pf.fun_codigo = %(funcod)s
    OR (NULLIF(%(pes_num_documento)s::varchar, '') IS NOT NULL AND p.pes_num_documento = %(pes_num_documento)s::varchar)
 ORDER BY (pf.fun_codigo = %(funcod)s) DESC
 LIMIT 1
