-- O imposto do MESMO TIPO que o produto ja tem no VarejoFacil (de preferencia o mesmo codigo) e quantos desse tipo
-- ele tem: se o codigo mudou ou ha mais de um do tipo (duplicidade de migracoes anteriores) -> atualizar.sql.
SELECT ip.impfedsim
     , (SELECT count(*) FROM impostos_federais_produto x
          JOIN impostos_federais fx ON fx.impfedsim = x.impfedsim
         WHERE x.procod = %(procod)s AND fx.impfedtip = f.impfedtip) AS qtd_mesmo_tipo
  FROM impostos_federais_produto ip
  JOIN impostos_federais f ON f.impfedsim = ip.impfedsim
 WHERE ip.procod = %(procod)s
   AND f.impfedtip = (SELECT impfedtip FROM impostos_federais WHERE impfedsim = %(impfedsim)s)
 ORDER BY (ip.impfedsim = %(impfedsim)s) DESC, ip.impfpid
 LIMIT 1
