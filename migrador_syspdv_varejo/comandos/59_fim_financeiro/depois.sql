-- Pentaho: "Insert Item Confiuguração Lançamento Financeiro" (Migrador_Inicial.kjb)
INSERT INTO item_configuracao_lancamento_financeiro (clf_id, cfnc_codigo, cc_codigo, iclf_valor, iclf_percentual)
     SELECT c.clf_id
          , c.cfnc_codigo
          , c.cc_codigo
          , clf_valor
          , 100
       FROM configuracao_lancamento_financeiro c
      WHERE NOT EXISTS(SELECT *
                         FROM item_configuracao_lancamento_financeiro i
                        WHERE i.clf_id = c.clf_id)
