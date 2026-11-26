-- descricao vem da classificacao_tributaria do VarejoFacil; criado_em nao e comparado
SELECT cfp_status, cfp_funcionario_cadastrou FROM cenario_fiscal_produto WHERE cfp_codigo = %(cfp_codigo)s
