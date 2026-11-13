-- Ja gravada: o titulo tem pelo menos "ordem" movimentos iguais a esta liquidacao.
SELECT 1 AS ja_gravada
  FROM (SELECT COUNT(*) AS qtd
          FROM movimentacao_titulo_receber m
         WHERE m.ttlr_id = (SELECT t.ttlr_id FROM titulo_a_receber t WHERE t.ctr_id = %(ctr_id)s AND t.ttlr_status = 'PARCIALMENTE_LIQUIDADO' ORDER BY t.ttlr_id LIMIT 1)
           AND m.mov_operacao = 'LIQUIDADO_PARCIALMENTE'
           AND m.mov_data = %(mov_data)s
           AND m.mov_valor IS NOT DISTINCT FROM %(mov_valor)s
           AND m.mov_juros IS NOT DISTINCT FROM %(mov_juros)s
           AND m.mov_multa IS NOT DISTINCT FROM %(mov_multa)s
           AND m.mov_desconto IS NOT DISTINCT FROM %(mov_desconto)s) q
 WHERE q.qtd >= %(ordem)s
