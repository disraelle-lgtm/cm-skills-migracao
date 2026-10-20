-- deixando default os eans principais e tributados para nao gerar duplicidade
update produtoaux set proeantrib = false, proeanprinc = false;

--DELETA PROCODAUX CASO SEJA IGUAL AO PROCOD 

DELETE 

  FROM produtoaux  

WHERE cast(procodaux AS BIGINT) IN (SELECT procod  

                                       FROM produto)  

   AND proauxtipo = 'EAN' ; 

 --TRANSFORMAR EM LITERAL OS EANS INVALIDOS 

UPDATE produtoaux  

   SET proauxtipo = 'LITERAL' 

     , proauxcodigoean = NULL 

     , proeantrib = FALSE  

WHERE validar_ean(procodaux) = FALSE ;   

UPDATE produtoaux  

   SET proauxtipo = 'LITERAL' 

     , proauxcodigoean = NULL 

     , proeantrib = FALSE  

WHERE validar_gs1(procodaux) = FALSE ;  

--DEFINIE COMO TRIBUTADO O EAN 

UPDATE produtoaux 
   SET proeantrib = TRUE 
 WHERE procodaux IN (SELECT DISTINCT ON (procod) procodaux 
                       FROM produtoaux 
                      WHERE proauxtipo = 'EAN'
                        AND procodaux::int8 > 999999999999 
                        AND procod NOT IN (SELECT DISTINCT procod 
                                             FROM produtoaux 
                                            WHERE proauxtipo = 'EAN' 
                                              AND proeantrib IS TRUE) 
                      ORDER BY procod
                          , proauxfat
                          , procodaux) ; 

--DEFINE EAN TRIBUTADO COMO PRINCIPAL 

UPDATE produtoaux  

   SET proeanprinc = TRUE  

WHERE proeantrib = TRUE ; 

  

UPDATE produtoaux  

   SET proeanprinc = TRUE  

WHERE proauxtipo = 'EAN'  

   AND procodaux IN (SELECT DISTINCT ON (procod)procodaux  

                       FROM produtoaux t1  

                      WHERE t1.procod NOT IN (SELECT DISTINCT t1.procod  

                                                FROM produto t1 JOIN produtoaux t2 ON t2.procod = t1.procod  

                                               WHERE proauxtipo = 'EAN'  

                                                 AND proeantrib = TRUE) 

                      ) ; 

  

UPDATE produtoaux  

   SET proeanprinc = FALSE  

WHERE proeanprinc IS NULL ;