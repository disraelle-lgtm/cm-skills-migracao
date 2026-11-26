SELECT impfeddes, impfedinc, impfedalq, impfedalqsai, impfedret
     , ipmfedobs, impfedtip, impfedst, impfedstsai, impfednatbas
  FROM impostos_federais
 WHERE impfedsim = %(impfedsim)s
