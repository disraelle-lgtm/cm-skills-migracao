INSERT INTO definicao_lancamento_financeiro_categoria (cfnc_codigo, dlf_cat_valor, dlf_cat_percentual, ctp_id)
     SELECT cfnc_codigo
          , ctp_valor_nominal
          , 100
          , ctp_id
       FROM conta_a_pagar c
      WHERE cfnc_codigo IS NOT NULL
        AND NOT EXISTS(SELECT * 
                         FROM definicao_lancamento_financeiro_categoria dc
                        WHERE dc.ctp_id = c.ctp_id) ;

INSERT INTO definicao_lancamento_financeiro_centro_custo (cc_codigo, dlf_cc_valor, dlf_cc_percentual, ctp_id) 
     SELECT 1
          , ctp_valor_nominal
          , 100
          , ctp_id
       FROM conta_a_pagar c
      WHERE NOT EXISTS(SELECT *
                         FROM definicao_lancamento_financeiro_centro_custo dc
                        WHERE dc.ctp_id = c.ctp_id) ;

INSERT INTO configuracao_lancamento_financeiro (loj_codigo, clf_tipo, clf_valor, clf_codigo_origem, clf_natureza, clf_documento, clf_historico, clf_data_lancamento, clf_data_emissao, clf_data_vencimento, pes_codigo, pes_nome, mcat_id, cfnc_codigo, cc_codigo, fun_codigo, clf_estorno)
     SELECT c.loj_codigo
          , 'TITULO_PAGAR'
          , c.ctp_valor_nominal
          , t.ttlp_id
          , 'DESPESA'
          , c.ctp_num_documento
          , NULL
          , c.ctp_data_emissao::DATE
          , c.ctp_data_emissao::DATE
          , t.ttlp_vencimento::DATE
          , p.pes_codigo
          , p.pes_fantasia
          , NULL
          , dc.cfnc_codigo
          , 1
          , NULL
          , FALSE
       FROM titulo_a_pagar t 
       JOIN conta_a_pagar c ON t.ctp_id  = c.ctp_id
       JOIN definicao_lancamento_financeiro_categoria dc ON dc.ctp_id = c.ctp_id
       LEFT JOIN pessoa_fornecedor pf ON pf.for_codigo = c.for_codigo 
       LEFT JOIN pessoa p ON p.pes_codigo = pf.pes_codigo 
      WHERE NOT EXISTS(SELECT *
                         FROM configuracao_lancamento_financeiro cc
                        WHERE cc.clf_codigo_origem = t.ttlp_id
                          AND cc.clf_tipo = 'TITULO_PAGAR') ;

INSERT INTO definicao_lancamento_financeiro_categoria (cfnc_codigo, dlf_cat_valor, dlf_cat_percentual, ctr_id) 
     SELECT cfnc_codigo
          , ctr_valor_nominal
          , 100
          , ctr_id
      FROM conta_a_receber c
     WHERE cfnc_codigo IS NOT NULL
       AND NOT EXISTS(SELECT * 
                        FROM definicao_lancamento_financeiro_categoria dc 
                       WHERE dc.ctr_id = c.ctr_id) ;

INSERT INTO definicao_lancamento_financeiro_centro_custo (cc_codigo, dlf_cc_valor, dlf_cc_percentual, ctr_id) 
     SELECT 1
          , ctr_valor_nominal
          , 100
          , ctr_id
       FROM conta_a_receber c 
      WHERE NOT EXISTS(SELECT * 
                         FROM definicao_lancamento_financeiro_centro_custo dc 
                        WHERE dc.ctr_id = c.ctr_id) ;


INSERT INTO configuracao_lancamento_financeiro (loj_codigo, clf_tipo, clf_valor, clf_codigo_origem, clf_natureza, clf_documento, clf_historico, clf_data_lancamento, clf_data_emissao, clf_data_vencimento, pes_codigo, pes_nome, mcat_id, cfnc_codigo, cc_codigo, fun_codigo, clf_estorno)
     SELECT c.loj_codigo
          , 'TITULO_RECEBER'
          , c.ctr_valor_nominal
          , t.ttlr_id
          , 'RECEITA'
          , c.ctr_num_documento
          , NULL
          , c.ctr_data_emissao::DATE
          , c.ctr_data_emissao::DATE
          , t.ttlr_vencimento::DATE
          , p.pes_codigo
          , p.pes_fantasia
          , NULL
          , dc.cfnc_codigo
          , 1
          , NULL
          , FALSE
       FROM titulo_a_receber t 
       JOIN conta_a_receber c ON t.ctr_id  = c.ctr_id
       JOIN definicao_lancamento_financeiro_categoria dc ON dc.ctr_id = c.ctr_id
       LEFT JOIN pessoa_cliente pc ON pc.cli_codigo = c.cli_codigo 
       LEFT JOIN pessoa p ON p.pes_codigo = pc.pes_codigo 
      WHERE NOT exists(SELECT *
                         FROM configuracao_lancamento_financeiro cc
                        WHERE cc.clf_codigo_origem = t.ttlr_id
                         AND cc.clf_tipo = 'TITULO_RECEBER') ;

INSERT INTO item_configuracao_lancamento_financeiro (clf_id, cfnc_codigo, cc_codigo, iclf_valor, iclf_percentual)
     SELECT c.clf_id
          , c.cfnc_codigo
          , c.cc_codigo
          , clf_valor
          , 100
       FROM configuracao_lancamento_financeiro c
      WHERE NOT EXISTS(SELECT *
                         FROM item_configuracao_lancamento_financeiro i
                        WHERE i.clf_id = c.clf_id) ;