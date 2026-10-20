/*
-- SCRIPT MIGRA PRECO DE UMA LOJA PARA OUTRA NO MESMO LINK VF
-- SETAR LOJA DE ORIGEM E DE DESTINO
*/

delete from preco where lojcod = 16 ; -- LOJA DESTINO

insert into preco (lojcod, procod, prcvdavar, prcofevar, prcmrg1, prcvda2, prcofe2, prcmrg2, prcqtdminprc2, prcvda3, prcofe3, prcmrg3, prcqtdminprc3, prccst, prcdtultre, prcpreco1, prcpreco2, prcpreco3, prcdcnmax, prcperdcn, prcid, proprccstmed, proprccstfis, prcori)
select 16 -- LOJA DESTINO
     , procod
     , prcvdavar
     , prcofevar
     , prcmrg1
     , prcvda2
     , prcofe2
     , prcmrg2
     , prcqtdminprc2
     , prcvda3
     , prcofe3
     , prcmrg3
     , prcqtdminprc3
     , prccst
     , prcdtultre
     , prcpreco1
     , prcpreco2
     , prcpreco3
     , prcdcnmax
     , prcperdcn
     , nextval('sq_preco')
     , proprccstmed
     , proprccstfis
     , prcori 
  from preco 
 where lojcod = 5 ; -- LOJA ORIGEM
