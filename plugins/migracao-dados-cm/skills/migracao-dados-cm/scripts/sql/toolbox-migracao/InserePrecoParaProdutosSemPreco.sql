-- INSERE PREÇO PARA PRODUTOS SEM PREÇO

INSERT INTO preco (lojcod, procod, prcvdavar, prcpreco1, prcdtultre, prcid)
     SELECT produto_loja.loj_codigo AS lojcod
          , produto_loja.procod
          , 0 AS prcvdavar
          , 0 AS prcpreco1
          , CURRENT_DATE AS prcdtultre
          , NEXTVAL('sq_preco') AS prcid
       FROM (SELECT p.procod
                  , l.loj_codigo
               FROM produto p
                  , pessoa_loja l
              ORDER BY 1) AS produto_loja
       LEFT JOIN preco pr ON (pr.procod = produto_loja.procod AND pr.lojcod = produto_loja.loj_codigo)
      WHERE pr.procod IS NULL 
        AND pr.lojcod IS NULL ;