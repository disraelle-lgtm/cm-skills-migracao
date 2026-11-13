-- No Pentaho a chave era o cd_id da sequence (duplicava a cada execucao); aqui loja + produto,
-- com os custos atualizados (Update = Y no Pentaho). A data nao e comparada.
SELECT cd_custo_fiscal AS custo_fiscal, cd_custo_reposicao AS custo_reposicao, cd_custo_medio AS custo_medio
  FROM custo_dia WHERE loj_codigo = %(loj_codigo)s AND procod = %(procod)s
 LIMIT 1
