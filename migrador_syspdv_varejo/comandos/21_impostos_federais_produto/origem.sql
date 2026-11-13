-- UM imposto por TIPO (PIS, COFINS, IRPJ, CSLL, OUTROS) para cada produto: o VarejoFacil so aceita 1 de cada.
-- Com mais de um do mesmo tipo no SysPDV, fica o de MENOR codigo, preferindo os impostos que o item Impostos
-- Federais migra (IMPFEDST <> IMPFEDSTSAI, ou com a situacao vazia). Os descartados aparecem no cartao (nao_lidos.sql).
-- SQL comum a Firebird e SQL Server.
SELECT i.IMPFEDSIM
     , i.PROCOD
     , f.IMPFEDTIP
  FROM IMPOSTOS_FEDERAIS_PRODUTO i
  JOIN IMPOSTOS_FEDERAIS f ON f.IMPFEDSIM = i.IMPFEDSIM
 WHERE i.PROCOD IN (SELECT p.PROCOD FROM PRODUTO p
                     WHERE p.PRODES IS NOT NULL
                       AND REPLACE(p.PROCOD, '0', '') <> ''
                       AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1))
   AND i.IMPFEDSIM = COALESCE(
         (SELECT MIN(i2.IMPFEDSIM) FROM IMPOSTOS_FEDERAIS_PRODUTO i2
            JOIN IMPOSTOS_FEDERAIS f2 ON f2.IMPFEDSIM = i2.IMPFEDSIM
           WHERE i2.PROCOD = i.PROCOD AND COALESCE(f2.IMPFEDTIP, '?') = COALESCE(f.IMPFEDTIP, '?')
             AND (f2.IMPFEDST IS NULL OR f2.IMPFEDSTSAI IS NULL OR f2.IMPFEDST <> f2.IMPFEDSTSAI)),
         (SELECT MIN(i3.IMPFEDSIM) FROM IMPOSTOS_FEDERAIS_PRODUTO i3
            JOIN IMPOSTOS_FEDERAIS f3 ON f3.IMPFEDSIM = i3.IMPFEDSIM
           WHERE i3.PROCOD = i.PROCOD AND COALESCE(f3.IMPFEDTIP, '?') = COALESCE(f.IMPFEDTIP, '?')))
 ORDER BY 2, 1
