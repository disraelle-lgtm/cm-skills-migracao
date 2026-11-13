UPDATE classificacao_tributaria
   SET ct_percentual_reducao_ibs = %(ct_percentual_reducao_ibs)s, ct_percentual_reducao_cbs = %(ct_percentual_reducao_cbs)s
 WHERE ct_codigo = %(ct_codigo)s
