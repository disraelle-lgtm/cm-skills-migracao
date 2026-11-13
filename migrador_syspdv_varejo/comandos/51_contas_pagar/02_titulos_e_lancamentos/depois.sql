-- Pentaho: T-TituloPagar_inicial - um titulo ABERTO por conta (chave ctp_id), ordem 1, prazo 1
INSERT INTO titulo_a_pagar (ttlp_id, ctp_id, ttlp_vencimento, ttlp_valor, ttlp_valor_liquido, ttlp_ordem, ttlp_prazo, ttlp_status)
SELECT nextval('sq_titulo_a_pagar'), c.ctp_id, c.ctp_primeiro_vencimento, c.ctp_valor_nominal, c.ctp_valor_nominal, 1, 1, 'ABERTO'
  FROM conta_a_pagar c
 WHERE NOT EXISTS (SELECT 1 FROM titulo_a_pagar t WHERE t.ctp_id = c.ctp_id);

-- Pentaho: T-MovimentacaoTituloPagar_inicial - INCLUSAO_DE_TITULO por titulo (chave ttlp_id).
-- No Pentaho o titulo era ligado a conta pelo VALOR (ttlp_valor = ctp_valor_nominal): contas com o
-- mesmo valor trocavam a data de emissao entre si. Aqui pelo ctp_id.
INSERT INTO movimentacao_titulo_pagar (mov_id, mov_operacao, ttlp_id, mov_valor, mov_data, mov_data_de_registro)
SELECT nextval('sq_movimentacao_titulo_pag'), 'INCLUSAO_DE_TITULO', tp.ttlp_id, tp.ttlp_valor, cp.ctp_data_emissao, NOW()
  FROM titulo_a_pagar tp
 INNER JOIN conta_a_pagar cp ON tp.ctp_id = cp.ctp_id
 WHERE NOT EXISTS (SELECT 1 FROM movimentacao_titulo_pagar m WHERE m.ttlp_id = tp.ttlp_id);

-- ------------------------------------------------ "VF - Atualiza Sequence"
select setval('SQ_CONTA_A_PAGAR', coalesce((select max(CTP_ID) from conta_a_pagar), 1));
select setval('sq_titulo_a_pagar', coalesce((select max(ttlp_id) from titulo_a_pagar), 1));
select setval('sq_movimentacao_titulo_pag', coalesce((select max(mov_id) from movimentacao_titulo_pagar), 1));

UPDATE conta_a_pagar
   SET ctp_num_documento = ctp_id
 WHERE ctp_num_documento IS NULL;

-- ------------------------------------------------ "VF - Ajusta Categoria Financeira"
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
                          AND cc.clf_tipo = 'TITULO_PAGAR');

-- O "VF - Insert Panama" do Pentaho NAO roda aqui: a fila do Panama e montada inteira no fim de toda
-- migracao pelo item automatico 99_fila_panama (InsertFilaPanama.sql, pedido do usuario).
