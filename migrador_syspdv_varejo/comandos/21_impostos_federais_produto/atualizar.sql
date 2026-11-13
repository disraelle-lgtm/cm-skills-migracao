-- Deixa UM imposto do tipo para o produto: o registro escolhido recebe o imposto do SysPDV e os demais do mesmo
-- tipo sao apagados (corrige duplicidades de migracoes anteriores).
WITH mesmo_tipo AS (
    SELECT ip.impfpid, ip.impfedsim
      FROM impostos_federais_produto ip
      JOIN impostos_federais f ON f.impfedsim = ip.impfedsim
     WHERE ip.procod = %(procod)s
       AND f.impfedtip = (SELECT impfedtip FROM impostos_federais WHERE impfedsim = %(impfedsim)s)
), alvo AS (
    SELECT impfpid FROM mesmo_tipo ORDER BY (impfedsim = %(impfedsim)s) DESC, impfpid LIMIT 1
), apaga AS (
    DELETE FROM impostos_federais_produto
     WHERE impfpid IN (SELECT impfpid FROM mesmo_tipo) AND impfpid NOT IN (SELECT impfpid FROM alvo)
    RETURNING impfpid
)
UPDATE impostos_federais_produto
   SET impfedsim = %(impfedsim)s
 WHERE impfpid IN (SELECT impfpid FROM alvo)
