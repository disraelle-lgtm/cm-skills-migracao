BEGIN ;

--replica preços tipo 1 para  tipos 2 e 3 da loja 2 
UPDATE preco p
   SET prcvda2 = (SELECT p1.prcvdavar FROM preco p1 WHERE p1.lojcod = 2 AND p1.procod = p.procod)
     , prcvda3 = (SELECT p1.prcvdavar FROM preco p1 WHERE p1.lojcod = 2 AND p1.procod = p.procod)
 WHERE lojcod = 2 ;

-- replicar qtd minima de preco 2 e 3 e margens da loja 3 para loja 4
UPDATE preco p
   SET prcqtdminprc2 = (SELECT p1.prcqtdminprc2 FROM preco p1 WHERE p1.lojcod = 3 AND p1.procod = p.procod)
     , prcqtdminprc3 = (SELECT p1.prcqtdminprc3 FROM preco p1 WHERE p1.lojcod = 3 AND p1.procod = p.procod)
     , prcmrg1 = (SELECT p1.prcmrg1 FROM preco p1 WHERE p1.lojcod = 3 AND p1.procod = p.procod)
     , prcmrg2 = (SELECT p1.prcmrg2 FROM preco p1 WHERE p1.lojcod = 3 AND p1.procod = p.procod)
     , prcmrg3 = (SELECT p1.prcmrg3 FROM preco p1 WHERE p1.lojcod = 3 AND p1.procod = p.procod)
 WHERE lojcod = 4 ;
