-- COMPLETAR O ESTOQUE EM TODAS AS LOJAS (pedido do usuario): todo produto precisa ter saldo - mesmo que zero - em TODAS
-- as lojas do VarejoFacil, senao o extrato / a posicao de estoque dao erro. Nada que ja existe e alterado.
-- 0) LOCAL DE ESTOQUE DA LOJA (local_da_loja): sem ele a tela do produto nao mostra o "Locais" daquela loja.
--    Local 1 para cada loja que ainda nao tem; na MATRIZ lcl_padrao / lcl_insumo = TRUE, nas outras NULL
--    (o mesmo comando que o usuario usava a mao). Sem restricao unica (loja, local) no VarejoFacil: NOT EXISTS.
INSERT INTO local_da_loja (lcl_id, loj_codigo, loc_codigo, lcl_padrao, lcl_insumo, id_externo)
SELECT NEXTVAL('sq_local_da_loja'), l.loj_codigo, 1,
       CASE WHEN l.loj_matriz = 'S' THEN TRUE END, CASE WHEN l.loj_matriz = 'S' THEN TRUE END, NULL
  FROM pessoa_loja l
 WHERE EXISTS (SELECT 1 FROM local_estoque le WHERE le.loc_codigo = 1)
   AND NOT EXISTS (SELECT 1 FROM local_da_loja x WHERE x.loj_codigo = l.loj_codigo AND x.loc_codigo = 1)
 ORDER BY l.loj_codigo;

-- 1) movimento de saldo zero (MIGRACAO) para cada produto x loja sem movimento no local 1
INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, loc_codigo, mov_quantidade, mov_data, mov_data_registro,
                                  mov_tipo, eta_codigo, mov_historico, fun_codigo)
SELECT NEXTVAL('sq_movimentacao_estoque'), p.procod, l.loj_codigo, 1, 0.00, CURRENT_DATE, CURRENT_DATE,
       'AJUSTE', 9002, 'MIGRACAO', 1
  FROM produto p
 CROSS JOIN pessoa_loja l
 WHERE NOT EXISTS (SELECT 1 FROM estoque_movimentacao em
                    WHERE em.procod = p.procod AND em.loj_codigo = l.loj_codigo AND em.loc_codigo = 1)
 ORDER BY l.loj_codigo, p.procod;

ANALYZE estoque_movimentacao;
ANALYZE estoque_resumo;

-- 2) a linha do resumo (o "Locais" da tela do produto) e CRIADA quando falta: com os gatilhos desligados na migracao,
--    o movimento nao cria o resumo, e o recalculo abaixo so atualiza linhas que ja existem
INSERT INTO estoque_resumo (res_id, procod, loj_codigo, loc_codigo, res_saldo)
SELECT NEXTVAL('sq_resumo_estoque'), mv.procod, mv.loj_codigo, 1, mv.saldo
  FROM (SELECT em.procod, em.loj_codigo, SUM(em.mov_quantidade) AS saldo
          FROM estoque_movimentacao em
         WHERE em.loc_codigo = 1
         GROUP BY em.procod, em.loj_codigo) mv
 WHERE NOT EXISTS (SELECT 1 FROM estoque_resumo er
                    WHERE er.procod = mv.procod AND er.loj_codigo = mv.loj_codigo AND er.loc_codigo = 1)
ON CONFLICT (procod, loj_codigo, loc_codigo) DO NOTHING;

-- 3) recalculo do saldo de TODAS as lojas (local 1) = soma dos movimentos
UPDATE estoque_resumo er
   SET res_saldo = COALESCE(mv.saldo, 0)
  FROM estoque_resumo base
  LEFT JOIN (SELECT em.procod, em.loj_codigo, SUM(em.mov_quantidade) AS saldo
               FROM estoque_movimentacao em
              WHERE em.loc_codigo = 1
              GROUP BY em.procod, em.loj_codigo) mv ON mv.procod = base.procod AND mv.loj_codigo = base.loj_codigo
 WHERE base.procod = er.procod AND base.loj_codigo = er.loj_codigo AND base.loc_codigo = er.loc_codigo
   AND er.loc_codigo = 1
   AND er.res_saldo IS DISTINCT FROM COALESCE(mv.saldo, 0);

-- 4) o estoque da loja (minimo / maximo) zerado para cada produto x loja que ainda nao tem
INSERT INTO produto_estoque (peq_id, procod, loj_codigo, peq_minimo, peq_maximo)
SELECT NEXTVAL('sq_produto_estoque'), p.procod, l.loj_codigo, 0, 0
  FROM produto p
 CROSS JOIN pessoa_loja l
 WHERE NOT EXISTS (SELECT 1 FROM produto_estoque pe WHERE pe.procod = p.procod AND pe.loj_codigo = l.loj_codigo)
