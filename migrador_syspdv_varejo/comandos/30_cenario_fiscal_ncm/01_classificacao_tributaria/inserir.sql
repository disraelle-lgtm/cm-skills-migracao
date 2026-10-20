INSERT INTO classificacao_tributaria (ct_codigo, cic_codigo, ct_nome, ct_descricao, ct_lc_redacao, ct_lc_214_25,
                                      ct_percentual_reducao_ibs, ct_percentual_reducao_cbs)
VALUES (%(ct_codigo)s, %(cic_codigo)s, %(ct_nome)s, %(ct_descricao)s, %(ct_lc_redacao)s, %(ct_lc_214_25)s,
        %(ct_percentual_reducao_ibs)s, %(ct_percentual_reducao_cbs)s)
