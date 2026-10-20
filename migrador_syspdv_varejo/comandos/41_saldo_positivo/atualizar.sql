-- O saldo mudou (ou ha movimentos MIGRACAO antigos, ex.: do "Zerar" do Pentaho): apaga os
-- movimentos MIGRACAO SO DESTE produto e lanca o saldo correto - fica um movimento so.
-- (Apagar produto a produto, e nao tudo de uma vez: marcando so "Saldo positivo", o saldo dos
-- produtos negativos nao e perdido.) Outros movimentos (que nao sao MIGRACAO) sao mantidos.
WITH apagados AS (
    DELETE FROM estoque_movimentacao
     WHERE procod = %(procod)s AND loj_codigo = %(loj_codigo)s AND loc_codigo = 1
       AND mov_historico = 'MIGRACAO'
    RETURNING mov_id
)
INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, mov_quantidade, mov_historico, eta_codigo,
                                  loc_codigo, mov_data, fun_codigo, mov_tipo, mov_data_registro)
SELECT nextval('sq_movimentacao_estoque'), %(procod)s, %(loj_codigo)s, %(mov_quantidade)s, 'MIGRACAO', 9002,
       1, %(mov_data)s, 1, 'AJUSTE', %(mov_data)s
