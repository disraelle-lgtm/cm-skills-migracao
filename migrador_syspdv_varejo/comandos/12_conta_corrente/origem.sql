-- Pentaho: FB - CONTA CORRENTE (cruzada com o PROPRIO para trazer o codigo da loja)
SELECT c.CTCCOD, c.CTCDES, c.CTCTIP, p.PRPCOD, c.AGECOD, c.CTCAGE, c.CTCNUM, c.CTCLOCPAG
  FROM CONTA_CORRENTE c
     , PROPRIO p
 ORDER BY 1
