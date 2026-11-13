INSERT INTO conta_a_pagar (ctp_id, ctp_data_emissao, ctp_primeiro_vencimento, ctp_observacao, ctp_valor_nominal,
                           ctp_valor_bruto, loj_codigo, for_codigo, agf_codigo, cfnc_codigo, ctp_modalidade,
                           ctp_dias_incidencia_juros, ctp_mora_diaria_atraso, ctp_dias_incidencia_multa,
                           ctp_valor_multa_por_atraso, ctp_numero_titulos, ctp_origem_documento, ctp_num_documento, edc_codigo)
VALUES (%(ctp_id)s, %(ctp_data_emissao)s, %(ctp_primeiro_vencimento)s, %(ctp_observacao)s, %(ctp_valor_nominal)s,
        %(ctp_valor_bruto)s, %(loj_codigo)s, %(for_codigo)s, 0, %(cfnc_codigo)s, 'S',
        0, 0, 0,
        0, 1, 'AVULSO', %(ctp_num_documento)s, 1)
