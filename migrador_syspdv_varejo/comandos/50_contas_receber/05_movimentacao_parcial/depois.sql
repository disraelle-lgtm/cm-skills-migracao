-- Pentaho: SQLs do fim do JOB-TituloReceber_inicial, na mesma ordem. O "VF - Ajuste Juros e Mora
-- Diaria" NAO e executado: juros e multa sao particulares de cada cliente (pedido do usuario).

-- ------------------------------------------------ "VF - Ajusta Sequence"
SELECT SETVAL('sq_conta_a_receber', COALESCE((SELECT MAX(ctr_id)  FROM conta_a_receber), 1));
SELECT SETVAL('sq_titulo_a_receber', COALESCE((SELECT MAX(ttlr_id) FROM titulo_a_receber), 1));
select SETVAL('sq_movimentacao_titulo_recb', COALESCE((select MAX(mov_id) from movimentacao_titulo_receber), 1));

UPDATE conta_a_receber
   SET ctr_num_documento = ctr_id
 WHERE ctr_num_documento IS NULL;

-- ------------------------------------------------ "VF - Ajusta Categoria Financeira"
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
      	                 AND cc.clf_tipo = 'TITULO_RECEBER');

-- O "VF - Insert Panama" do Pentaho NAO roda aqui: a fila do Panama e montada inteira no fim de toda
-- migracao pelo item automatico 99_fila_panama (InsertFilaPanama.sql, pedido do usuario).
