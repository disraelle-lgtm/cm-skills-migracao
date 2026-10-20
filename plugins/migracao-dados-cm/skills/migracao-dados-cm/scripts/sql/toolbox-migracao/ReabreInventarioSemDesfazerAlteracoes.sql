-- apenas reabre o inventário (sem desafazer as alterações)

DO LANGUAGE plpgsql $$
DECLARE
    ID BIGINT;
BEGIN
    -- colocar o código do inventário.
    ID := ID;
    RAISE NOTICE '% - REABRINDO INVENTÁRIO [%] SEM DESFAZER AS ALTERAÇÕES...', timeofday()::timestamp, ID;
    
    DELETE FROM HISTORICO_INVENTARIO 
          WHERE IVT_ID = ID 
            AND HIN_STATUS NOT IN ('ABERTO','CONGELADO');
    
    DELETE FROM ESTOQUE_MOVIMENTACAO
          WHERE IIVT_ID IN (SELECT T1.IIVT_ID
                              FROM ITEM_INVENTARIO T1
                             WHERE IVT_ID = ID);

    UPDATE INVENTARIO 
       SET IVT_STATUS = 'ABERTO' 
     WHERE IVT_ID = ID ;

    RAISE NOTICE '% - INVENTÁRIO [%] REABERTO.', timeofday()::timestamp, ID;
END;
$$;