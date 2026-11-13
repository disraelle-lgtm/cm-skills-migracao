-- Pentaho: chave (lojcod, procod); todos os precos com Update = Y
SELECT prcdcnmax, prcvdavar, prcofevar, prcdtultre, prccst, prcvda2, prcofe2, prcvda3, prcofe3, prcpreco1, prcpreco2, prcpreco3, prcperdcn, prcmrg1, prcmrg2, prcmrg3, proprccstmed, proprccstfis, prcqtdminprc2, prcqtdminprc3
  FROM preco
 WHERE lojcod = %(lojcod)s AND procod = %(procod)s
