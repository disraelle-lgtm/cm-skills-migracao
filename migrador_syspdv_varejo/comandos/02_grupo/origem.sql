-- ORIGEM: so grupos cuja secao existe, exceto a secao '00' (regra do Pentaho).
SELECT SECCOD
     , GRPCOD
     , GRPDES
  FROM GRUPO
 WHERE SECCOD IN (SELECT SECCOD FROM SECAO)
   AND SECCOD <> '00'
 ORDER BY 1, 2
