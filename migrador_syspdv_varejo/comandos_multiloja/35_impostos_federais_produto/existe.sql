SELECT ip.impfedsim
     , (SELECT count(*) FROM impostos_federais_produto x
          JOIN impostos_federais fx ON fx.impfedsim = x.impfedsim
         WHERE x.procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND fx.impfedtip = f.impfedtip) AS qtd_mesmo_tipo
  FROM impostos_federais_produto ip
  JOIN impostos_federais f ON f.impfedsim = ip.impfedsim
 WHERE ip.procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
   AND f.impfedtip = (SELECT impfedtip FROM impostos_federais WHERE impfedsim = %(impfedsim)s)
 ORDER BY (ip.impfedsim = %(impfedsim)s) DESC, ip.impfpid
 LIMIT 1
