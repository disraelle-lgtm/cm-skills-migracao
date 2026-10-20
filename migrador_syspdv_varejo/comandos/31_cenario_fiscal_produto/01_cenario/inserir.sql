-- descricao: Merge Join com a classificacao_tributaria do VarejoFacil (corte 200 + TRIM)
INSERT INTO cenario_fiscal_produto (cfp_codigo, ct_codigo, cic_codigo, cfp_descricao, cfp_funcionario_cadastrou, cfp_status, criado_em)
VALUES (%(cfp_codigo)s, %(ct_codigo)s::varchar, %(cic_codigo)s::varchar, (SELECT LEFT(TRIM(ct_descricao), 200) FROM classificacao_tributaria WHERE ct_codigo = %(ct_codigo)s::varchar), %(cfp_funcionario_cadastrou)s, %(cfp_status)s, now())
