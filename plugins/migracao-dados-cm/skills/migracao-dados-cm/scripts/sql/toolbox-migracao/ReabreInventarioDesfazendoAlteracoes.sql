-- reabre o inventário desafazendo as alterações

DO LANGUAGE plpgsql $$
DECLARE
    ID BIGINT;
BEGIN
    -- colocar o código do inventário.
    ID := ID;
    RAISE NOTICE '% - REABRINDO INVENTÁRIO [%] DESFAZENDO ALTERAÇÕES...', timeofday()::timestamp, ID;
    
    DELETE FROM HISTORICO_INVENTARIO 
          WHERE IVT_ID = ID 
            AND HIN_STATUS NOT IN ('ABERTO','CONGELADO');
    
    DELETE FROM ESTOQUE_MOVIMENTACAO
          WHERE IIVT_ID IN (SELECT T1.IIVT_ID
                              FROM ITEM_INVENTARIO T1
                             WHERE IVT_ID = ID);

    UPDATE ITEM_INVENTARIO 
       SET IIVT_PRIMEIRA_DIGITACAO = NULL 
     WHERE IVT_ID = ID 
       AND IIVT_PRIMEIRA_DIGITACAO = 0 ;

    UPDATE INVENTARIO 
       SET IVT_STATUS = 'ABERTO' 
     WHERE IVT_ID = ID ;

    RAISE NOTICE '% - INVENTÁRIO [%] REABERTO.', timeofday()::timestamp, ID;
END;
$$;