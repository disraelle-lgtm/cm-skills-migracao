-- Codigo zerado (00, 000, ...) nao e lido (REPLACE(...,'0','') <> '' vale para Firebird e SQL Server).
-- ORIGEM: so subgrupos com secao e grupo existentes, exceto a secao '00'.
SELECT b.SECCOD
     , b.GRPCOD
     , b.SGRCOD
     , b.SGRDES
  FROM SUBGRUPO b
 INNER JOIN SECAO s ON (s.SECCOD = b.SECCOD)
 INNER JOIN GRUPO g ON (g.SECCOD = b.SECCOD AND g.GRPCOD = b.GRPCOD)
 WHERE b.SECCOD <> '00'
   AND REPLACE(b.GRPCOD, '0', '') <> ''
   AND REPLACE(b.SGRCOD, '0', '') <> ''
 ORDER BY 1, 2, 3
