CREATE OR REPLACE FUNCTION public.descobre_proximo_codigo()
    RETURNS BIGINT AS
$BODY$
    DECLARE
        proximo_codigo BIGINT;

    BEGIN

           SELECT CASE 
                     WHEN (SELECT MIN(p1.procod)
                             FROM produto p1
                            WHERE procod NOT IN (SELECT CAST(procodaux AS BIGINT) AS procod
                                                   FROM produtoaux
                                                  WHERE procodaux ~* '^[0-9]*$'
                                                    AND CHAR_LENGTH(procodaux) < 15 
                              AND p1.procod > 999999)) > 1 THEN 1
                     WHEN (SELECT MIN(p1.procod)
                             FROM produto p1
                            WHERE procod NOT IN (SELECT CAST(procodaux AS BIGINT) AS procod
                                                   FROM produtoaux 
                                                  WHERE procodaux ~* '^[0-9]*$'
                                                    AND CHAR_LENGTH(procodaux) < 15 )
                              AND p1.procod > 999999) IS NULL THEN 1
                     ELSE (SELECT MIN(p1.procod + 1)
                             FROM (SELECT procod AS procod
                                     FROM produto
                                    UNION
                                   SELECT CAST(procodaux AS BIGINT) AS procod
                                     FROM produtoaux
                                    WHERE procodaux ~* '^[0-9]*$'
                                      AND CHAR_LENGTH(procodaux) < 15) p1
                             LEFT JOIN (SELECT procod - 1 AS procod
                                          FROM produto
                                         union
                                        SELECT CAST(procodaux AS BIGINT) - 1 AS procod
                                          FROM produtoaux WHERE procodaux ~* '^[0-9]*$'
                                           AND CHAR_LENGTH(procodaux) < 15) p2 ON p1.procod = p2.procod
                            WHERE P2.PROCOD IS NULL
                              AND p1.procod > 999999)
                   END AS codigo
                   INTO proximo_codigo
           ;
    RETURN proximo_codigo;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

  --DROP FUNCTION descobre_proximo_codigo() ;