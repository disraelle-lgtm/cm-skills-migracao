-- INSERT ESTOQUE MOVIMENTACAO

INSERT INTO estoque_tipo_ajuste (eta_codigo, eta_descricao, eta_tipo, eta_tipo_reservado, id_externo) VALUES(9001, 'AJUSTES DE MIGRACAO',   'SAIDA', 'AJUSTE_MIGRACAO', NULL);
INSERT INTO estoque_tipo_ajuste (eta_codigo, eta_descricao, eta_tipo, eta_tipo_reservado, id_externo) VALUES(9002, 'AJUSTES DE MIGRACAO', 'ENTRADA', 'AJUSTE_MIGRACAO', NULL);

INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, loc_codigo, mov_quantidade, mov_data, mov_data_registro, mov_tipo, eta_codigo, mov_historico, fun_codigo)
SELECT NEXTVAL('sq_movimentacao_estoque')
     , procod
     , 1
     , 1 
     , 0.00
     , CURRENT_DATE
     , CURRENT_DATE
     , 'AJUSTE'
     , 9002
     , 'MIGRACAO'
     , 1
  FROM produto ;