-- Pentaho: chave ct_codigo; so os % de reducao com Update = Y
SELECT ct_percentual_reducao_ibs, ct_percentual_reducao_cbs FROM classificacao_tributaria WHERE ct_codigo = %(ct_codigo)s
