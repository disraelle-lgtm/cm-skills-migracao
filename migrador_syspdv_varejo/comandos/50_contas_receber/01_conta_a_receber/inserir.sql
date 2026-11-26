INSERT INTO conta_a_receber (ctr_id, cli_codigo, loj_codigo, ctr_num_documento, ctr_observacao, ctr_data_emissao,
                             ctr_primeiro_vencimento, ctr_valor_nominal, ctr_valor_bruto, cfnc_codigo, agf_codigo,
                             ctr_dias_incidencia_juros, ctr_mora_diaria_atraso, ctr_dias_incidencia_multa,
                             ctr_valor_multa_por_atraso, ctr_condicao_pagamento, ctr_numero_titulos, ctr_modalidade,
                             ctr_origem_documento, edc_codigo)
VALUES (%(ctr_id)s, %(cli_codigo)s, %(loj_codigo)s, %(ctr_num_documento)s, %(ctr_observacao)s, %(ctr_data_emissao)s,
        %(ctr_primeiro_vencimento)s, %(ctr_valor_nominal)s, %(ctr_valor_bruto)s, %(cfnc_codigo)s, 0,
        0, 0, 0,
        0, 'A_VISTA', 1, 'S',
        'AVULSO', (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1))
