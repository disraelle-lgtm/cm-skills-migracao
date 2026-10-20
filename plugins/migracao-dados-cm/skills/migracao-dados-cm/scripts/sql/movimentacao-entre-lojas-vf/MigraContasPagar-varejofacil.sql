/*
-- SCRIPT MIGRA CONTAS A PAGAR EM ABERTO E PARCIALMENTE LIQUIDADOS DE UMA LOJA PARA OUTRA NO MESMO LINK VF
- SETAR LOJA DE ORIGEM E DE DESTINO
*/

-- Setando sequencies.
SELECT SETVAL(         'sq_conta_a_pagar', COALESCE((SELECT  MAX(ctp_id) FROM             conta_a_pagar), 1));
SELECT SETVAL(        'sq_titulo_a_pagar', COALESCE((SELECT MAX(ttlp_id) FROM            titulo_a_pagar), 1));
SELECT SETVAL('sq_movimentacao_titulo_pag', COALESCE((SELECT  MAX(mov_id) from movimentacao_titulo_pagar), 1));

-- ROLLBACK ;
-- BEGIN ;

-- Criando coluna temporária na tabela conta_a_pagar .
ALTER TABLE conta_a_pagar ADD COLUMN ttlp_id_origem INT8 ;

-- Inserindo registros de contas parcialmente liquidadas na tabela conta a pagar.
INSERT INTO conta_a_pagar (ttlp_id_origem, ctp_id, ctp_data_emissao, ctp_primeiro_vencimento, ctp_observacao, ctp_valor_nominal, ctp_valor_bruto, loj_codigo, for_codigo, agf_codigo, cfnc_codigo, ctp_modalidade, ctp_dias_incidencia_juros, ctp_mora_diaria_atraso, ctp_dias_incidencia_multa, ctp_valor_multa_por_atraso, ctp_numero_titulos, ctp_origem_documento, ctp_num_documento, edc_codigo, ctp_tipo_valor_mora_diaria)
SELECT    tp.ttlp_id
          , NEXTVAL('sq_conta_a_pagar')
          , cp.ctp_data_emissao
          , case 
            when (tp.ttlp_vencimento < tp.ttlp_ultimo_pagamento)  then tp.ttlp_ultimo_pagamento  
            else ttlp_vencimento
            end
          , cp.ctp_observacao
          , tp.ttlp_saldo
          , tp.ttlp_saldo
          , 16 --lj destino
          , cp.for_codigo
          , cp.agf_codigo
          , cp.cfnc_codigo
          , cp.ctp_modalidade
          , cp.ctp_dias_incidencia_juros
          , cp.ctp_mora_diaria_atraso
          , cp.ctp_dias_incidencia_multa
          , cp.ctp_valor_multa_por_atraso
          , 1
          , cp.ctp_origem_documento
          , cp.ctp_num_documento
          , cp.edc_codigo
          , cp.ctp_tipo_valor_mora_diaria
       FROM conta_a_pagar cp
       JOIN titulo_a_pagar tp ON cp.ctp_id = tp.ctp_id
       join movimentacao_titulo_pagar mtr on tp.ttlp_id = mtr.ttlp_id
       JOIN (SELECT max(mtp.mov_id) AS mov
               FROM movimentacao_titulo_pagar mtp
               JOIN titulo_a_pagar tp ON mtp.ttlp_id = tp.ttlp_id
               JOIN conta_a_pagar cp ON (tp.ctp_id = cp.ctp_id AND tp.ttlp_id = mtp.ttlp_id)
              WHERE tp.ttlp_status IN ('PARCIALMENTE_LIQUIDADO')
                AND cp.loj_codigo = 5 --lj origem
              GROUP BY tp.ttlp_id) id ON id.mov = mtr.mov_id
      WHERE tp.ttlp_status IN ('PARCIALMENTE_LIQUIDADO')
        AND cp.loj_codigo = 5 ;--lj origem


-- Inserindo registros de contas em abertas na tabela conta a pagar.
INSERT INTO conta_a_pagar (ttlp_id_origem, ctp_id, ctp_data_emissao, ctp_primeiro_vencimento, ctp_observacao, ctp_valor_nominal, ctp_valor_bruto, loj_codigo, for_codigo, agf_codigo, cfnc_codigo, ctp_modalidade, ctp_dias_incidencia_juros, ctp_mora_diaria_atraso, ctp_dias_incidencia_multa, ctp_valor_multa_por_atraso, ctp_numero_titulos, ctp_origem_documento, ctp_num_documento, edc_codigo, ctp_tipo_valor_mora_diaria)
     SELECT tp.ttlp_id
          , NEXTVAL('sq_conta_a_pagar')
          , cp.ctp_data_emissao
          , tp.ttlp_vencimento
          , cp.ctp_observacao
          , tp.ttlp_valor
          , tp.ttlp_valor
          , 16 --lj destino
          , cp.for_codigo
          , cp.agf_codigo
          , cp.cfnc_codigo
          , cp.ctp_modalidade
          , cp.ctp_dias_incidencia_juros
          , cp.ctp_mora_diaria_atraso
          , cp.ctp_dias_incidencia_multa
          , cp.ctp_valor_multa_por_atraso
          , cp.ctp_numero_titulos
          , cp.ctp_origem_documento
          , cp.ctp_num_documento
          , cp.edc_codigo
          , cp.ctp_tipo_valor_mora_diaria
       FROM conta_a_pagar cp
       JOIN titulo_a_pagar tp ON cp.ctp_id = tp.ctp_id
      WHERE tp.ttlp_status IN ('ABERTO')
        AND cp.loj_codigo = 5 ;--lj origem

-- Inserindo registros na tabelas de titulos a pagar.
INSERT INTO titulo_a_pagar (ttlp_vencimento, ttlp_valor, ctp_id, ttlp_ordem, ttlp_prazo, ttlp_status, ttlp_id, ttlp_valor_liquido)  
      SELECT cp.ctp_primeiro_vencimento
           , ctp_valor_nominal
           , cp.ctp_id
           , 1
           , tp.ttlp_prazo
           , 'ABERTO'
           , NEXTVAL('sq_titulo_a_pagar')
           , cp.ctp_valor_nominal
        FROM conta_a_pagar cp
        JOIN titulo_a_pagar tp ON cp.ttlp_id_origem = tp.ttlp_id
       WHERE cp.ttlp_id_origem IS NOT NULL ;

-- Inserindo resgistro na tabela de movimentação de titulo a pagar.
INSERT INTO movimentacao_titulo_pagar (mov_id, mov_operacao, ttlp_id, mov_valor, mov_data, mov_data_de_registro)
    SELECT NEXTVAL('sq_movimentacao_titulo_pag')
         , 'INCLUSAO_DE_TITULO'
         , tp.ttlp_id
         , tp.ttlp_valor
         , cp.ctp_data_emissao
         , current_date
      FROM titulo_a_pagar tp
      JOIN conta_a_pagar cp ON (tp.ctp_id = cp.ctp_id AND cp.ttlp_id_origem IS NOT NULL) ;

--corrigir contas a pagar sem categoria financeira, validar qual a categoria usada pelo cliente.
update conta_a_pagar
   set cfnc_codigo = 32
 where cfnc_codigo is null 
   and ttlp_id_origem is not null;

-- Inserts padrões para levar a movimentação financeira.
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
select setval('SQ_CONTA_A_PAGAR', coalesce((select max(CTP_ID) from conta_a_pagar), 1));
select setval('sq_titulo_a_pagar', coalesce((select max(ttlp_id) from titulo_a_pagar), 1));
select setval('sq_movimentacao_titulo_pag', coalesce((select max(mov_id) from movimentacao_titulo_pagar), 1));

--COMMIT ;

--Dropando coluna temporária. O drop da coluna deve ser realizado depois do commit.
ALTER TABLE conta_a_pagar DROP COLUMN ttlp_id_origem;

