-- Pentaho: FB - LOCAL (so locais ativos)
SELECT LOCCOD
     , LOCDES
  FROM LOCAL
 WHERE LOCSTATUS = 'A'
