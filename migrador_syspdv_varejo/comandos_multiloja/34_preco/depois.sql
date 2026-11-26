-- Pentaho: T-Corrige-PrecosZerados_inicial ("Trata precos negativos" e "Trata desconto maximo")
UPDATE preco SET prccst = 0 WHERE prccst < 0;
UPDATE preco SET proprccstfis = 0 WHERE proprccstfis < 0;
UPDATE preco SET proprccstmed = 0 WHERE proprccstmed < 0;
UPDATE preco SET prcmrg1 = 0 WHERE prcmrg1 < 0;
UPDATE preco SET prcvdavar = 0 WHERE prcvdavar IS NULL;
UPDATE preco SET prcdcnmax = 99.99 WHERE prcdcnmax > 99;

SET session_replication_role = DEFAULT;

-- ESPELHA PRECO (pedido do usuario; o Pentaho multi loja fazia o mesmo): toda loja do VarejoFacil que AINDA NAO tem
-- preco para um produto recebe a copia de uma loja que tem - da MATRIZ quando ela tem preco; senao da loja que esta
-- sendo migrada; senao da de menor codigo. Preco que ja existe NUNCA e alterado (cada loja mantem o seu); quando a
-- outra loja for migrada, o item Preco atualiza a copia para o preco proprio dela.
ANALYZE preco;
WITH matriz AS (
    SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1
), fonte AS (
    SELECT DISTINCT ON (pr.procod) pr.*
      FROM preco pr
     ORDER BY pr.procod, (pr.lojcod = (SELECT loj_codigo FROM matriz)) DESC, (pr.lojcod = {{loja_destino}}) DESC, pr.lojcod
)
INSERT INTO preco (prcid, lojcod, procod, prcdcnmax, prcvdavar, prcofevar, prcdtultre, prccst, prcvda2, prcofe2, prcvda3, prcofe3, prcpreco1, prcpreco2, prcpreco3, prcperdcn, prcmrg1, prcmrg2, prcmrg3, proprccstmed, proprccstfis, prcqtdminprc2, prcqtdminprc3)
SELECT nextval('sq_preco'), l.loj_codigo, f.procod, f.prcdcnmax, f.prcvdavar, f.prcofevar, f.prcdtultre, f.prccst, f.prcvda2, f.prcofe2, f.prcvda3, f.prcofe3, f.prcpreco1, f.prcpreco2, f.prcpreco3, f.prcperdcn, f.prcmrg1, f.prcmrg2, f.prcmrg3, f.proprccstmed, f.proprccstfis, f.prcqtdminprc2, f.prcqtdminprc3
  FROM fonte f
 CROSS JOIN pessoa_loja l
 WHERE NOT EXISTS (SELECT 1 FROM preco x WHERE x.procod = f.procod AND x.lojcod = l.loj_codigo);
