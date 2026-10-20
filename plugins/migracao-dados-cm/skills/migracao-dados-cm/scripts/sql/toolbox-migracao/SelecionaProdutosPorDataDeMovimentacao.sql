-- SELECIONA PRODUTO POR PERÍODO DE MOVIMENTAÇÃO

SELECT *
  FROM produto
 WHERE proforlin = 'N'
   AND procod IN (SELECT procod 
                    FROM produto 
                   WHERE procod IN (SELECT procod 
                                      FROM itevda i
                                     WHERE trndat >= '01.12.2021'
                                     GROUP BY procod)
                      OR procod IN (SELECT inf.procod 
                                      FROM item_nota_fiscal inf 
                                      JOIN notafiscal n ON n.nfsctr = inf.nfsctr
                                     WHERE n.nfsdatemi >= '01.12.2021' 
                                     GROUP BY procod)
                      OR procod IN (SELECT procod
                                      FROM estoque_movimentacao
                                     where (movtip in ('V', 'E', 'C', 'T', 'N')
                                       AND movdat >= '01.12.2021')
                                     GROUP BY procod)
                      OR prodatcadinc >= '01.12.2021'); 