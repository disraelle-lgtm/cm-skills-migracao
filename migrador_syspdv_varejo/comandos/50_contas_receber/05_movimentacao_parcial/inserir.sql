INSERT INTO movimentacao_titulo_receber (mov_id, mov_operacao, ttlr_id, mov_valor, mov_data, mov_data_de_registro,
                                         mov_dias_em_atraso, fzdcod, mov_juros, mov_multa, mov_desconto, cct_codigo, mov_usuario)
VALUES (nextval('sq_movimentacao_titulo_recb'), 'LIQUIDADO_PARCIALMENTE', (SELECT t.ttlr_id FROM titulo_a_receber t WHERE t.ctr_id = %(ctr_id)s AND t.ttlr_status = 'PARCIALMENTE_LIQUIDADO' ORDER BY t.ttlr_id LIMIT 1), %(mov_valor)s, %(mov_data)s, %(mov_data)s,
        0, 1, %(mov_juros)s, %(mov_multa)s, %(mov_desconto)s, %(cct_codigo)s, 1)
