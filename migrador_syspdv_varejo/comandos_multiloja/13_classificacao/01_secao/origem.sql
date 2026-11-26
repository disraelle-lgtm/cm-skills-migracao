-- ORIGEM: SysPDV (Firebird). Roda uma vez e devolve as linhas a migrar.
-- Regra do Pentaho: a secao '00' nunca e migrada.
SELECT SECCOD
     , SECDES
  FROM SECAO
 WHERE SECCOD <> '00'
 ORDER BY 1
