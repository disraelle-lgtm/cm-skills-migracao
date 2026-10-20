SELECT *
  FROM dbo.referencia r 
  JOIN dbo.produto p on r.procod = p.procod
 WHERE r.refforlin != 'S'
   AND p.prodes IS NOT NULL
   AND r.refplu IN ( SELECT refplu
                       FROM extrato_estoque 
                      WHERE extdat >='2018.01.01'
                      GROUP BY refplu)
 ORDER BY p.procod ;
