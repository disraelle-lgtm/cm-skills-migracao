UPDATE preco
   SET prcdcnmax = %(prcdcnmax)s
     , prcvdavar = %(prcvdavar)s
     , prcofevar = %(prcofevar)s
     , prcdtultre = %(prcdtultre)s
     , prccst = %(prccst)s
     , prcvda2 = %(prcvda2)s
     , prcofe2 = %(prcofe2)s
     , prcvda3 = %(prcvda3)s
     , prcofe3 = %(prcofe3)s
     , prcpreco1 = %(prcpreco1)s
     , prcpreco2 = %(prcpreco2)s
     , prcpreco3 = %(prcpreco3)s
     , prcperdcn = %(prcperdcn)s
     , prcmrg1 = %(prcmrg1)s
     , prcmrg2 = %(prcmrg2)s
     , prcmrg3 = %(prcmrg3)s
     , proprccstmed = %(proprccstmed)s
     , proprccstfis = %(proprccstfis)s
     , prcqtdminprc2 = %(prcqtdminprc2)s
     , prcqtdminprc3 = %(prcqtdminprc3)s
 WHERE lojcod = %(lojcod)s AND procod = %(procod)s
