UPDATE cenario_fiscal_produto
   SET cfp_funcionario_cadastrou = %(cfp_funcionario_cadastrou)s, cfp_status = %(cfp_status)s, criado_em = now()
 WHERE cfp_codigo = %(cfp_codigo)s
