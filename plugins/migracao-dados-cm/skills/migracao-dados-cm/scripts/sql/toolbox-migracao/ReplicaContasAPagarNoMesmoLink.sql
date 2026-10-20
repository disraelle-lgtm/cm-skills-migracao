BEGIN ;

ALTER TABLE conta_a_pagar ADD COLUMN ctp_id_origem INT8;

INSERT INTO conta_a_pagar (ctp_id_origem, ctp_id, ctp_data_emissao, ctp_primeiro_vencimento, ctp_observacao, ctp_valor_nominal, ctp_valor_bruto, loj_codigo, for_codigo, agf_codigo, cfnc_codigo, ctp_modalidade, ctp_dias_incidencia_juros, ctp_mora_diaria_atraso, ctp_dias_incidencia_multa, ctp_valor_multa_por_atraso, ctp_numero_titulos, ctp_origem_documento, ctp_num_documento, edc_codigo)
     SELECT ctp_id
          , NEXTVAL('sq_conta_a_pagar')
          , ctp_data_emissao
          , ctp_primeiro_vencimento
          , ctp_observacao
          , ctp_valor_nominal
          , ctp_valor_bruto
          , $LOJA_DE_DESTINO
          , for_codigo
          , agf_codigo
          , cfnc_codigo
          , ctp_modalidade
          , ctp_dias_incidencia_juros
          , ctp_mora_diaria_atraso
          , ctp_dias_incidencia_multa
          , ctp_valor_multa_por_atraso
          , ctp_numero_titulos
          , ctp_origem_documento
          , ctp_num_documento
          , edc_codigo
       FROM conta_a_pagar
      WHERE	ctp_id IN (SELECT ctp_id
                         FROM titulo_a_pagar
                        WHERE ttlp_status IN ('ABERTO', 'PARCIALMENTE_LIQUIDADO')
        AND loj_codigo = $CODIGO_LOJA;

INSERT INTO titulo_a_pagar (ttlp_vencimento, ttlp_valor, ctp_id, ttlp_ordem, ttlp_prazo, ttlp_status, ttlp_id, ttlp_valor_liquido)
      SELECT ctp_primeiro_vencimento
           , ctp_valor_nominal
           , ctp_id
           , 1
           , 1
           , 'ABERTO'
           , NEXTVAL('sq_titulo_a_pagar')
           , ctp_valor_nominal
        FROM conta_a_pagar
       WHERE ctp_id_origem IS NOT NULL ;

INSERT INTO movimentacao_titulo_pagar (mov_id, mov_operacao, ttlp_id, mov_valor, mov_data, mov_data_de_registro)
    SELECT NEXTVAL('sq_movimentacao_titulo_pag')
         , 'INCLUSAO_DE_TITULO'
         , tp.ttlp_id
         , tp.ttlp_valor
         , cp.ctp_data_emissao
         , current_date
      FROM titulo_a_pagar tp
      JOIN conta_a_pagar cp ON (tp.ctp_id = cp.ctp_id AND cp.ctp_id_origem IS NOT NULL) ;

ALTER TABLE conta_a_pagar DROP COLUMN ctp_id_origem ;

COMMIT ;