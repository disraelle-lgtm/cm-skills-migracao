SELECT prcdcnmax, prcvdavar, prcofevar, prcdtultre, prccst, prcvda2, prcofe2, prcvda3, prcofe3, prcpreco1, prcpreco2, prcpreco3, prcperdcn, prcmrg1, prcmrg2, prcmrg3, proprccstmed, proprccstfis, prcqtdminprc2, prcqtdminprc3
  FROM preco
 WHERE lojcod = {{loja_destino}} AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
