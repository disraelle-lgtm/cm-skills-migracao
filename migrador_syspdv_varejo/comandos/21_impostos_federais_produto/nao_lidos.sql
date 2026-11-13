-- Ligacoes produto x imposto que ficaram de fora porque o produto ja tem outro imposto do MESMO tipo
-- (o VarejoFacil aceita 1 PIS, 1 COFINS... por produto) ou porque o imposto nao existe no SysPDV.
-- Sem concatenacao de texto (|| no Firebird, + no SQL Server): colunas separadas.
SELECT i.PROCOD AS REGISTRO
     , i.IMPFEDSIM AS DESCRICAO
     , CASE WHEN f.IMPFEDSIM IS NULL THEN 'o imposto não existe no cadastro de Impostos Federais do SysPDV'
            WHEN f.IMPFEDTIP = 'P' THEN 'o produto já tem outro PIS (fica o de menor código): o VarejoFácil aceita 1 PIS por produto'
            WHEN f.IMPFEDTIP = 'C' THEN 'o produto já tem outro COFINS (fica o de menor código): o VarejoFácil aceita 1 COFINS por produto'
            WHEN f.IMPFEDTIP = 'I' THEN 'o produto já tem outro IRPJ (fica o de menor código): o VarejoFácil aceita 1 IRPJ por produto'
            WHEN f.IMPFEDTIP = 'S' THEN 'o produto já tem outro CSLL (fica o de menor código): o VarejoFácil aceita 1 CSLL por produto'
            ELSE 'o produto já tem outro imposto do mesmo tipo (fica o de menor código): o VarejoFácil aceita 1 por tipo'
       END AS MOTIVO
     , f.IMPFEDDES AS DESCRICAO_IMPOSTO
     , f.IMPFEDTIP AS TIPO
  FROM IMPOSTOS_FEDERAIS_PRODUTO i
  LEFT JOIN IMPOSTOS_FEDERAIS f ON f.IMPFEDSIM = i.IMPFEDSIM
 WHERE i.PROCOD IN (SELECT p.PROCOD FROM PRODUTO p
                     WHERE p.PRODES IS NOT NULL
                       AND REPLACE(p.PROCOD, '0', '') <> ''
                       AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1))
   AND (f.IMPFEDSIM IS NULL OR i.IMPFEDSIM <> COALESCE(
         (SELECT MIN(i2.IMPFEDSIM) FROM IMPOSTOS_FEDERAIS_PRODUTO i2
            JOIN IMPOSTOS_FEDERAIS f2 ON f2.IMPFEDSIM = i2.IMPFEDSIM
           WHERE i2.PROCOD = i.PROCOD AND COALESCE(f2.IMPFEDTIP, '?') = COALESCE(f.IMPFEDTIP, '?')
             AND (f2.IMPFEDST IS NULL OR f2.IMPFEDSTSAI IS NULL OR f2.IMPFEDST <> f2.IMPFEDSTSAI)),
         (SELECT MIN(i3.IMPFEDSIM) FROM IMPOSTOS_FEDERAIS_PRODUTO i3
            JOIN IMPOSTOS_FEDERAIS f3 ON f3.IMPFEDSIM = i3.IMPFEDSIM
           WHERE i3.PROCOD = i.PROCOD AND COALESCE(f3.IMPFEDTIP, '?') = COALESCE(f.IMPFEDTIP, '?'))))
 ORDER BY 1, 2
