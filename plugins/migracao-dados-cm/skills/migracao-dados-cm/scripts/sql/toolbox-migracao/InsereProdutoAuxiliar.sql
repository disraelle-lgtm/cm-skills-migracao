-- INSERE PRODUTO AUXILIAR

INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
SELECT lpad(codigo_produto_antigo::VARCHAR(14), 14, '0')
     , procod
     , 1
     , 'EAN'
     , SUBSTRING(LPAD(codigo_produto_antigo::VARCHAR(14), 14, '0') FROM 1 FOR 13)::INT8
     , TRUE
     , TRUE
  FROM produto 
 WHERE proenvbal = 'N'
 ORDER BY 2 ;