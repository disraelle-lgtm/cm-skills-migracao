/*
-- SCRIPT MIGRA O SALDO DE ESTOQUE DE UMA LOJA PARA OUTRA NO MESMO LINK VF
-- SETAR LOJA DE ORIGEM E DE DESTINO
*/

-- Comando de inserir o estoque com base na estoque_resumo

INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, loc_codigo, mov_quantidade, mov_data, mov_data_registro, mov_tipo, eta_codigo, mov_historico, fun_codigo)
SELECT NEXTVAL('sq_movimentacao_estoque')
    , procod
    , 16 -- LOJA DESTINO
    , loc_codigo
    , res_saldo
    , CURRENT_DATE
    , CURRENT_DATE
    , 'AJUSTE'
    , 9002
    , 'MIGRACAO'
    , 1
FROM estoque_resumo where loj_codigo = 5 ; -- LOJA ORIGEM
