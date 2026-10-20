-- SCRIPT DE SETAR PRECO 0 PARA OS PRODUTOS QUE NAO ESTAO NA TABELA PRECO

INSERT INTO preco (lojcod, procod, prcvdavar, prcpreco1, prcdtultre, prcid, prcperdcn, proprccstmed, proprccstfis, prcori)
     SELECT produto_loja.loj_codigo AS lojcod
          , produto_loja.procod AS procod
          , 0 AS prcvdavar
          , 0 AS prcpreco1
          , current_date AS prcdtultre
          , NEXTVAL('sq_preco') AS prcid
          , 'N' AS prcperdcn
          , 0 AS proprccstmed
          , 0 AS proprccstfis
          , 'CADASTRO' AS prcori
       FROM (SELECT p.procod
       	          , l.loj_codigo
       	       FROM produto p
       	          , pessoa_loja l
       	      ORDER by 1) AS produto_loja
       LEFT JOIN preco pr ON (pr.procod = produto_loja.procod AND pr.lojcod = produto_loja.loj_codigo)
      WHERE pr.procod IS NULL
        AND pr.lojcod IS NULL ;