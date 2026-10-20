-- INSERE IMPOSTOS FEDERAIS E IMPOSTOS FEDERAIS PRODUTOS PADRÕES

INSERT INTO impostos_federais (impfedsim, impfeddes, impfedinc, impfedalq, impfedret, ipmfedobs, impfedtip, impfedalqsai, impfedst, impfedstsai, impfednatbas, impfedstpre, impfedstsaipre, impfedalqpre, impfedalqsaipre, impfedstsim, impfedstsaisim, impfedgeralid, impfedatacadoid, impfedvarejoid, impfedsimplesid, id_externo) VALUES('01',    'PIS 98 49', NULL, 0.0000, 0.0000, NULL,    'PIS', 0.0000, '98', '49', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 1, 1, 1, NULL) ;
INSERT INTO impostos_federais (impfedsim, impfeddes, impfedinc, impfedalq, impfedret, ipmfedobs, impfedtip, impfedalqsai, impfedst, impfedstsai, impfednatbas, impfedstpre, impfedstsaipre, impfedalqpre, impfedalqsaipre, impfedstsim, impfedstsaisim, impfedgeralid, impfedatacadoid, impfedvarejoid, impfedsimplesid, id_externo) VALUES('02', 'COFINS 98 49', NULL, 0.0000, 0.0000, NULL, 'COFINS', 0.0000, '98', '49', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 2, 2, 2, 2, NULL) ;

INSERT INTO impostos_federais_geral (impfedgeralid, impfedst, impfedalq, impfedstsai, impfedalqsai)
     SELECT impfedgeralid
          , impfedst
          , impfedalq
          , impfedstsai
          , impfedalqsai 
       FROM impostos_federais ;

INSERT INTO impostos_federais_atacado (impfedatacadoid)
     SELECT impfedatacadoid 
       FROM impostos_federais ;

INSERT INTO impostos_federais_simples (impfedsimplesid)
     SELECT impfedsimplesid
       FROM impostos_federais ;

INSERT INTO impostos_federais_varejo (impfedvarejoid)
     SELECT impfedvarejoid
       FROM impostos_federais ;

SELECT SETVAL(  'sq_impostos_federais_geral',   (SELECT MAX(impfedgeralid) + 1 FROM   impostos_federais_geral), FALSE) ;
SELECT SETVAL('sq_impostos_federais_atacado', (SELECT MAX(impfedatacadoid) + 1 FROM impostos_federais_atacado), FALSE) ;
SELECT SETVAL('sq_impostos_federais_simples', (SELECT MAX(impfedsimplesid) + 1 FROM impostos_federais_simples), FALSE) ;
SELECT SETVAL( 'sq_impostos_federais_varejo',  (SELECT MAX(impfedvarejoid) + 1 FROM  impostos_federais_varejo), FALSE) ;
-----------------------------------------------------------------------------------------------------
INSERT INTO impostos_federais_produto (impfpid, impfedsim, procod)
     SELECT NEXTVAL('sq_impostos_federais_produto')
          , '01'
          , procod
       FROM produto ;

INSERT INTO impostos_federais_produto (impfpid, impfedsim, procod)
     SELECT NEXTVAL('sq_impostos_federais_produto')
          , '02'
          , procod
       FROM produto ;