BEGIN ;

-- INSERIR FUNCIONÁRIOS NO PANAMA

INSERT INTO FILA_SINCRONIZACAO_PANAMA (id, origem, identificador, prioridade, entidade_id, operacao, objeto_id)
     SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
          , 'VFCLI'
          , 'VENDA'
          , 2
          , venda.id
          , 'EXCLUSAO'
          , venda.id
       FROM (SELECT t.trnseq::TEXT||'-'||t.cxanum::TEXT||'-'||t.lojcod::TEXT||'-'||TO_CHAR(t.trndat, 'yyyy-MM-dd') AS id
               FROM transacao t
              WHERE t.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                AND t.lojcod IN (1)
                AND NOT EXISTS (SELECT 1
                                  FROM item_venda iv
                                  JOIN item_devolucao_cupom ic ON (ic.id_item_venda = iv.id)
                                 WHERE 1 = 1
                                   AND iv.lojcod IN (1)
                                   AND iv.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                                   AND iv.trndat = t.trndat
                                   AND iv.trnseq = t.trnseq
                                   AND iv.cxanum = t.cxanum
                                   AND iv.lojcod = t.lojcod)
                AND NOT EXISTS (SELECT 1
                                  FROM item_venda iv
                                  JOIN estoque_movimentacao em ON (em.id_item_venda = iv.id)
                                  JOIN item_inventario ii ON (ii.mov_id = em.mov_id)
                                 WHERE 1 = 1
                                   AND iv.lojcod IN (1)
                                   AND iv.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                                   AND iv.trndat = t.trndat
                                   AND iv.trnseq = t.trnseq
                                   AND iv.cxanum = t.cxanum
                                   AND iv.lojcod = t.lojcod)) venda ;

INSERT INTO fila_sincronizacao_panama (id, origem, identificador, prioridade, entidade_id, operacao, objeto_id)
     SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
          , 'VFCLI'
          , 'TROCA_FORMA_PAGAMENTO'
          , 2
          , troca.id
          , 'EXCLUSAO'
          , troca.id
       FROM (SELECT i.id::TEXT AS id
               FROM troca_finalizacao i
               JOIN transacao t ON (i.trndat = t.trndat AND i.trnseq = t.trnseq AND i.cxanum = t.cxanum AND i.lojcod = t.lojcod)
              WHERE t.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                AND t.lojcod IN (1)
                AND NOT EXISTS (SELECT 1
                                  FROM item_venda iv
                                  JOIN item_devolucao_cupom ic ON (ic.id_item_venda = iv.id)
                                 WHERE 1 = 1
                                   AND iv.lojcod IN (1)
                                   AND iv.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                                   AND iv.trndat = t.trndat
                                   AND iv.trnseq = t.trnseq
                                   AND iv.cxanum = t.cxanum
                                   AND iv.lojcod = t.lojcod)
                AND NOT EXISTS (SELECT 1
                                  FROM item_venda iv
                                  JOIN estoque_movimentacao em ON (em.id_item_venda = iv.id)
                                  JOIN item_inventario ii ON (ii.mov_id = em.mov_id)
                                 WHERE 1 = 1
                                   AND iv.lojcod IN (1)
                                   AND iv.trndat BETWEEN '2019-08-31' AND '2019-08-31'
                                   AND iv.trndat = t.trndat
                                   AND iv.trnseq = t.trnseq
                                   AND iv.cxanum = t.cxanum
                                   AND iv.lojcod = t.lojcod)) troca ;