-- Setando sequencies.
SELECT SETVAL(         'sq_conta_a_receber', COALESCE((SELECT  MAX(ctr_id) FROM             conta_a_receber), 1));
SELECT SETVAL(        'sq_titulo_a_receber', COALESCE((SELECT MAX(ttlr_id) FROM            titulo_a_receber), 1));
SELECT SETVAL('sq_movimentacao_titulo_recb', COALESCE((SELECT  MAX(mov_id) from movimentacao_titulo_receber), 1));

-- ROLLBACK ;
-- BEGIN ;

-- Criando coluna temporária na tabela conta_a_receber .
ALTER TABLE conta_a_receber ADD COLUMN ttlr_id_origem INT8 ;

-- Inserindo registros de contas parcialmente liquidadas na tabela conta a receber.
INSERT INTO conta_a_receber (ttlr_id_origem, ctr_id, ctr_data_emissao, ctr_primeiro_vencimento, ctr_observacao, ctr_valor_nominal, ctr_valor_bruto, loj_codigo, cli_codigo, agf_codigo, cfnc_codigo, ctr_modalidade, ctr_dias_incidencia_juros, ctr_mora_diaria_atraso, ctr_dias_incidencia_multa, ctr_valor_multa_por_atraso, ctr_numero_titulos, ctr_origem_documento, ctr_num_documento, edc_codigo, ctr_tipo_valor_mora_diaria)
     SELECT tr.ttlr_id
          , NEXTVAL('sq_conta_a_receber')
          , cr.ctr_data_emissao
          , mtr.mov_data
          , cr.ctr_observacao
          , tr.ttlr_saldo
          , tr.ttlr_saldo
          , 12
          , cr.cli_codigo
          , cr.agf_codigo
          , cr.cfnc_codigo
          , cr.ctr_modalidade
          , cr.ctr_dias_incidencia_juros
          , cr.ctr_mora_diaria_atraso
          , cr.ctr_dias_incidencia_multa
          , cr.ctr_valor_multa_por_atraso
          , 1
          , cr.ctr_origem_documento
          , cr.ctr_num_documento
          , cr.edc_codigo
          , cr.ctr_tipo_valor_mora_diaria
       FROM conta_a_receber cr
       JOIN titulo_a_receber tr ON cr.ctr_id = tr.ctr_id
       join movimentacao_titulo_receber mtr on tr.ttlr_id = mtr.ttlr_id
       JOIN (SELECT max(mtr.mov_id) AS mov
               FROM movimentacao_titulo_receber mtr
               JOIN titulo_a_receber tr ON mtr.ttlr_id = tr.ttlr_id
               JOIN conta_a_receber cr ON (tr.ctr_id = cr.ctr_id AND tr.ttlr_id = mtr.ttlr_id)
              WHERE tr.ttlr_status IN ('PARCIALMENTE_LIQUIDADO')
                AND cr.loj_codigo = 2
              GROUP BY tr.ttlr_id) id ON id.mov = mtr.mov_id
      WHERE tr.ttlr_status IN ('PARCIALMENTE_LIQUIDADO')
        AND cr.loj_codigo = 2 ;

-- Inserindo registros de contas em abertas na tabela conta a receber.
INSERT INTO conta_a_receber (ttlr_id_origem, ctr_id, ctr_data_emissao, ctr_primeiro_vencimento, ctr_observacao, ctr_valor_nominal, ctr_valor_bruto, loj_codigo, cli_codigo, agf_codigo, cfnc_codigo, ctr_modalidade, ctr_dias_incidencia_juros, ctr_mora_diaria_atraso, ctr_dias_incidencia_multa, ctr_valor_multa_por_atraso, ctr_numero_titulos, ctr_origem_documento, ctr_num_documento, edc_codigo, ctr_tipo_valor_mora_diaria)
     SELECT tr.ttlr_id
          , NEXTVAL('sq_conta_a_receber')
          , cr.ctr_data_emissao
          , tr.ttlr_vencimento
          , cr.ctr_observacao
          , tr.ttlr_valor
          , tr.ttlr_valor
          , 12
          , cr.cli_codigo
          , cr.agf_codigo
          , cr.cfnc_codigo
          , cr.ctr_modalidade
          , cr.ctr_dias_incidencia_juros
          , cr.ctr_mora_diaria_atraso
          , cr.ctr_dias_incidencia_multa
          , cr.ctr_valor_multa_por_atraso
          , cr.ctr_numero_titulos
          , cr.ctr_origem_documento
          , cr.ctr_num_documento
          , cr.edc_codigo
          , cr.ctr_tipo_valor_mora_diaria
       FROM conta_a_receber cr
       JOIN titulo_a_receber tr ON cr.ctr_id = tr.ctr_id
      WHERE tr.ttlr_status IN ('ABERTO')
        AND cr.loj_codigo = 2 ;

-- Inserindo registros na tabelas de titulos a receber.
INSERT INTO titulo_a_receber (ttlr_vencimento, ttlr_valor, ctr_id, ttlr_ordem, ttlr_prazo, ttlr_status, ttlr_id, ttlr_valor_liquido)
      SELECT cr.ctr_primeiro_vencimento
           , ctr_valor_nominal
           , cr.ctr_id
           , 1
           , tr.ttlr_prazo
           , 'ABERTO'
           , NEXTVAL('sq_titulo_a_receber')
           , cr.ctr_valor_nominal
        FROM conta_a_receber cr
        JOIN titulo_a_receber tr ON cr.ttlr_id_origem = tr.ttlr_id
       WHERE cr.ttlr_id_origem IS NOT NULL ;

-- Inserindo resgistro na tabela de movimentação de titulo a receber.
INSERT INTO movimentacao_titulo_receber (mov_id, mov_operacao, ttlr_id, mov_valor, mov_data, mov_data_de_registro)
    SELECT NEXTVAL('sq_movimentacao_titulo_recb')
         , 'INCLUSAO_DE_TITULO'
         , tr.ttlr_id
         , tr.ttlr_valor
         , cr.ctr_data_emissao
         , current_date
      FROM titulo_a_receber tr
      JOIN conta_a_receber cr ON (tr.ctr_id = cr.ctr_id AND cr.ttlr_id_origem IS NOT NULL) ;

-- Inserts padrões para levar a movimentação financeira.
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

-- Atualizando as sequencies.
SELECT SETVAL(         'sq_conta_a_receber', COALESCE((SELECT  MAX(ctr_id) FROM             conta_a_receber), 1));
SELECT SETVAL(        'sq_titulo_a_receber', COALESCE((SELECT MAX(ttlr_id) FROM            titulo_a_receber), 1));
SELECT SETVAL('sq_movimentacao_titulo_recb', COALESCE((SELECT  MAX(mov_id) from movimentacao_titulo_receber), 1));

--COMMIT ;

--Dropando coluna temporária. O drop da coluna deve ser realizado depois do commit.
ALTER TABLE conta_a_receber DROP COLUMN ttlr_id_origem;


