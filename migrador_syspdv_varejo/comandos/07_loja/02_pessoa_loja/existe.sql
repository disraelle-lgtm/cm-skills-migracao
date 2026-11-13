-- Pentaho: Insert/Update pela chave PRPCOD = loj_codigo
SELECT loj_chave_server, loj_versao_server, loj_regime_federal, loj_crt, loj_porta, loj_ip, loj_matriz, loj_preco_aplicado, fig_codigo, ret_codigo, loj_sigla, loj_regime_municipal, loj_perfil, loj_atividade, cfnc_codigo_est_pag, cfnc_codigo_est_receb, cfnc_codigo_pagamentos, cfnc_codigo_recebimentos, cfnc_codigo_quebra, cfnc_codigo_sobra, loj_nome_exibicao
  FROM pessoa_loja
 WHERE loj_codigo = %(loj_codigo)s
