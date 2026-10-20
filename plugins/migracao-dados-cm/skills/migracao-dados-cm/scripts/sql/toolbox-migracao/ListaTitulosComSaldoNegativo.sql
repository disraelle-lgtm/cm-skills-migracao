-- LISTA TITULOS COM SALDO NEGATIVO

WITH cte_clientes_saldo_errado AS ( SELECT cli_codigo
                                      FROM limite_de_credito ldc
                                     WHERE ldc.lcr_valor - (SELECT SUM(ttlr_saldo)
                                                              FROM titulo_a_receber tar
                                                             WHERE tar.ctr_id IN (SELECT car.ctr_id
                                                                                    FROM conta_a_receber car
                                                                                   WHERE car.cli_codigo = ldc.cli_codigo
                                                                                     AND car.edc_codigo = ldc.edc_codigo
                                                                                     AND car.ctr_origem_documento != 'CARTAO_CREDITO')
                                                                                     AND ttlr_status IN ('ABERTO', 'ABERTO_E_PENDENTE', 'PARCIALMENTE_LIQUIDADO')
                                                           ) > ldc.lcr_valor
                                       AND ldc.lcr_situacao = 'BLOQUEADO')
SELECT mtr.ttlr_id
  FROM movimentacao_titulo_receber mtr
 WHERE mtr.ttlr_id IN ( SELECT tar.ttlr_id
                          FROM titulo_a_receber tar
                         WHERE tar.ctr_id IN ( SELECT car.ctr_id
                                                 FROM conta_a_receber car
                                                 JOIN CTE_CLIENTES_SALDO_ERRADO CTE ON car.cli_codigo = cte.cli_codigo
                                                WHERE car.ctr_origem_documento != 'CARTAO_CREDITO')
                           AND ttlr_status IN ('ABERTO', 'ABERTO_E_PENDENTE', 'PARCIALMENTE_LIQUIDADO')
                           AND ttlr_saldo < 0)
   AND mtr.mov_saldo < 0 ;