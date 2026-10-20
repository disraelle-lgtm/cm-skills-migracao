-- Pentaho: T-Corrige-PrecosZerados_inicial ("Trata precos negativos" e "Trata desconto maximo")
UPDATE preco SET prccst = 0 WHERE prccst < 0;
UPDATE preco SET proprccstfis = 0 WHERE proprccstfis < 0;
UPDATE preco SET proprccstmed = 0 WHERE proprccstmed < 0;
UPDATE preco SET prcmrg1 = 0 WHERE prcmrg1 < 0;
UPDATE preco SET prcvdavar = 0 WHERE prcvdavar IS NULL;
UPDATE preco SET prcdcnmax = 99.99 WHERE prcdcnmax > 99;

SET session_replication_role = DEFAULT
