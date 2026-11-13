-- Os 4 IDs vem das sequences, igual ao Pentaho (sq_imp_fed_geral/atacado/simples/varejo).
INSERT INTO impostos_federais
      (impfedsim, impfeddes, impfedinc, impfedalq, impfedalqsai, impfedret
     , ipmfedobs, impfedtip, impfedst, impfedstsai, impfednatbas
     , impfedgeralid, impfedatacadoid, impfedsimplesid, impfedvarejoid)
VALUES (%(impfedsim)s, %(impfeddes)s, %(impfedinc)s, %(impfedalq)s, %(impfedalqsai)s, %(impfedret)s
     , %(ipmfedobs)s, %(impfedtip)s, %(impfedst)s, %(impfedstsai)s, %(impfednatbas)s
     , nextval('sq_impostos_federais_geral'), nextval('sq_impostos_federais_atacado')
     , nextval('sq_impostos_federais_simples'), nextval('sq_impostos_federais_varejo'))
