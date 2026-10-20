CREATE OR REPLACE FUNCTION HABILITA_OU_DESABILITA_CONSTRANTS(HABILITA_TRIGER BOOLEAN) RETURNS VOID AS
$BODY$
DECLARE
    NOME_TABELA VARCHAR;
BEGIN
    FOR NOME_TABELA IN
    SELECT C.RELNAME
      FROM PG_CLASS AS C
     INNER JOIN PG_ATTRIBUTE AS A ON (A.ATTRELID = C.OID)
     WHERE (UPPER(A.ATTNAME) IN (UPPER('PROCOD'), UPPER('CODIGO_PRODUTO'), UPPER('ID_PRODUTO'), UPPER('RES_CODIGO_PRODUTO'))
        OR  UPPER(A.ATTNAME) LIKE UPPER('%_PROCOD'))
       AND UPPER(C.RELKIND) = 'R'
       AND UPPER(C.RELNAME) NOT IN ('PG_PROC', 'PG_OPERATOR', 'PG_AMPROC', 'PG_CONVERSION', 'PG_SECLABEL',
                                    'PG_SHSECLABEL', 'SQL_LANGUAGES', 'SQL_SIZING_PROFILES', 'ESTATISTICA_PRODUTO_MOVIMENTACAO',
                                    'ESTATISTICA_PRODUTO_VENDA', 'ESTATISTICA_PRODUTO_COMPRA', 'ESTOQUE_DIA', 'ESTOQUE_RESUMO','ESTOQUE_MOVIMENTACAO')
    LOOP
        IF HABILITA_TRIGER THEN
            EXECUTE 'ALTER TABLE ' || NOME_TABELA || ' ENABLE TRIGGER ALL ' ;
        ELSE
            EXECUTE 'ALTER TABLE ' || NOME_TABELA || ' DISABLE TRIGGER ALL ' ;
        END IF;
    END LOOP;

END
$BODY$
LANGUAGE 'plpgsql' ;

CREATE OR REPLACE FUNCTION REPROCESSAR_VENDA_CONSOLIDADA_A_PARTIR_DE(PERIODO DATE) RETURNS INT AS $$
    BEGIN
        PERFORM REPROCESSAR_VENDA_CONSOLIDADA_NO_PERIODO(PERIODO, NULL::DATE); 
        RETURN 1;
    END;
$$ LANGUAGE 'plpgsql' ;

CREATE OR REPLACE FUNCTION reprocessar_venda_consolidada_no_periodo(inicio date, fim date) RETURNS int AS $$
    BEGIN

        DELETE FROM VENDA_CONSOLIDADA_PRODUTO WHERE VCPDAT >= INICIO AND (FIM IS NULL OR VCPDAT <= FIM);
        DELETE FROM VENDA_CONSOLIDADA_FINALIZADORA WHERE VCFDAT >= INICIO AND (FIM IS NULL OR VCFDAT <= FIM);
        DELETE FROM VENDA_CONSOLIDADA_LOJA WHERE VCLDAT >= INICIO AND (FIM IS NULL OR VCLDAT <= FIM);

        INSERT INTO VENDA_CONSOLIDADA_PRODUTO (ID, LOJCOD, VCPDAT, PROCOD, VCPQTD, VCPVLRTOT, VALOR_LUCRO_MARKUP, VALOR_LUCRO_MARGEM, VALOR_CUSTO)
        SELECT NEXTVAL('SQ_VENDA_CONSOLIDADA_PRODUTO')
             , V.LOJCOD
             , V.TRNDAT AS VCPDAT
             , V.PROCOD AS PROCOD
             , SUM(V.ITVQTDVDA) AS VCPQTD
             , SUM(V.ITVVLRTOT) AS VCPVLRTOT
             , SUM(V.ITVVLRTOT - (V.ITVPRCCST * V.ITVQTDVDA)) AS VALOR_LUCRO_MARKUP
             , SUM(V.ITVVLRTOT - (V.ITVVLRTOT * V.ITVTRBALQ / 100) - (V.ITVVLRTOT * V.ITVALQPIS / 100) - (V.ITVVLRTOT * V.ITVALQCOFINS / 100) - (V.ITVPRCCSTFIS * V.ITVQTDVDA)) AS VALOR_LUCRO_MARGEM
             , SUM(V.ITVPRCCST * V.ITVQTDVDA) AS VALOR_CUSTO
          FROM VENDA V
         WHERE V.TRNDAT >= INICIO AND (FIM IS NULL OR V.TRNDAT <= FIM)
         GROUP BY V.LOJCOD, V.TRNDAT, V.PROCOD;

        INSERT INTO VENDA_CONSOLIDADA_FINALIZADORA (ID, LOJCOD, VCFDAT, FZDCOD, VCFVLRTOT, VCFQTDCLI)
        SELECT NEXTVAL('SQ_VENDA_CONSOLIDADA_FIN')
             , R.LOJCOD
             , R.TRNDAT
             , R.FZDCOD
             , SUM(R.VCLVLRTOT) VCLVLRTOT
             , COUNT(*) AS VCLQTDCLI
          FROM (SELECT V.LOJCOD
                     , V.TRNDAT
                     , V.CXANUM
                     , V.TRNSEQ
                     , V.FZDCOD
                     , SUM(V.FZCVLR) VCLVLRTOT
                  FROM VENDA_FINALIZADORA V
                 WHERE V.TRNDAT >= INICIO AND (FIM IS NULL OR V.TRNDAT <= FIM)
                 GROUP BY V.LOJCOD, V.TRNDAT, V.CXANUM, V.TRNSEQ, V.FZDCOD) R
         GROUP BY R.LOJCOD,R.TRNDAT,R.FZDCOD;

        INSERT INTO VENDA_CONSOLIDADA_LOJA (ID, LOJCOD, VCLDAT, VCLQTDCLI, VCLVLRTOT, TOTAL_LUCRO_MARKUP, TOTAL_LUCRO_MARGEM, TOTAL_CUSTO, VCLVLRSER)
        SELECT NEXTVAL('SQ_VENDA_CONSOLIDADA_LOJA'), V.LOJCOD, V.TRNDAT AS VCPDAT
            , COUNT(DISTINCT LOJCOD::TEXT||TRNDAT::TEXT||CXANUM||TRNSEQ) AS VCLQTDCLI
            , SUM(V.ITVVLRTOT) AS VCPVLRTOT
            , SUM(V.ITVVLRTOT - (V.ITVPRCCST * V.ITVQTDVDA)) AS TOTAL_LUCRO_MARKUP
            , SUM(V.ITVVLRTOT - (V.ITVVLRTOT * V.ITVTRBALQ / 100) - (V.ITVVLRTOT * V.ITVALQPIS / 100) - (V.ITVVLRTOT * V.ITVALQCOFINS / 100) - (V.ITVPRCCSTFIS * V.ITVQTDVDA)) AS TOTAL_LUCRO_MARGEM
            , SUM(V.ITVPRCCST * V.ITVQTDVDA) AS TOTAL_CUSTO
            , SUM(V.ITVVLRSER) AS VCLVLRSER
        FROM VENDA V
        WHERE V.TRNDAT >= INICIO AND (FIM IS NULL OR V.TRNDAT <= FIM)
        GROUP BY V.LOJCOD, V.TRNDAT;
        RETURN 1;
    END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION EXCLUIR_PRODUTO_COM_MOVIMENTACAO(CODIGO_ANTIGO BIGINT, CODIGO_NOVO BIGINT) RETURNS VOID AS
$BODY$
DECLARE
    NOME_TABELA VARCHAR;
    NOME_COLUNA VARCHAR;

    CODIGO_SECAO_PRODUTO_ANTIGO BIGINT;
    CODIGO_SECAO_PRODUTO_NOVO BIGINT;

    INVENTARIOS_COM_OS_2_PRODUTOS BIGINT;
BEGIN
    -- Valida se as seções dos produtos é o mesmo
    SELECT SECCOD
      INTO CODIGO_SECAO_PRODUTO_ANTIGO
      FROM PRODUTO
     WHERE PROCOD = CODIGO_ANTIGO
    ;

    SELECT SECCOD
      INTO CODIGO_SECAO_PRODUTO_NOVO
      FROM PRODUTO
     WHERE PROCOD = CODIGO_NOVO
    ;

    IF CODIGO_SECAO_PRODUTO_ANTIGO <> CODIGO_SECAO_PRODUTO_NOVO THEN
        RAISE EXCEPTION 'PRODUTO NÃO PODE SER TRANSFERIDO' USING HINT = 'OS PRODUTOS NÃO TEM A MESMA SEÇÃO';
        RETURN;
    END IF;

    -- Desabilita as contrants das tabelas que tem alguma relação com produto
    -- PERFORM HABILITA_OU_DESABILITA_CONSTRANTS(FALSE) ;

    -- Atualiza o código de produto em algumas tabelas especificas
    UPDATE ASSISTENTE_COMPRA_PRODUTO     SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ASSISTENTE_COMPRA_ITEM        SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ALTERACAO_PRODUTO_SPED        SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    --UPDATE BI_VENDAS                     SET CODIGO_PRODUTO = CODIGO_NOVO WHERE CODIGO_PRODUTO = CODIGO_ANTIGO ;
    UPDATE DETALHE_CONFIGURACAO_COMISSAO SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_NOTA_FISCAL              SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_NOTA_FISCAL_BKP          SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_AJUSTE_ESTOQUE           SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_PRODUCAO_COMPOSICAO      SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_VENDA                    SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_TRANSFERENCIA            SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_NOTA_DEVOLUCAO           SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_PEDIDO_COMPRA            SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_PEDIDO_VENDA             SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_PREVENDA_ECOMMERCE       SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE PRODUTO_ESTOQUE               SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE PREMIO                        SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE PRODUCAO_COMPOSICAO           SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE PRODUTO_SUGESTAO_COMPRA       SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE PROMOCAO_PREMIACAO_PROD       SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE REGIME_PRODUTO_LOJA           SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE RENDIMENTO_PRODUTO            SET CODIGO_PRODUTO = CODIGO_NOVO WHERE CODIGO_PRODUTO = CODIGO_ANTIGO ;
    UPDATE COMISSAO                      SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE CONFIGURACAO_COMISSAO         SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;
    UPDATE ITEM_DEVOLUCAO_CUPOM          SET ID_PRODUTO     = CODIGO_NOVO WHERE ID_PRODUTO     = CODIGO_ANTIGO ;
    UPDATE CONFERENCIA_PRODUTO           SET PROCOD         = CODIGO_NOVO WHERE PROCOD         = CODIGO_ANTIGO ;

    UPDATE RESGATE_NETPOINTS SET RES_CODIGO_PRODUTO = CAST(CODIGO_NOVO AS NUMERIC) WHERE RES_CODIGO_PRODUTO = CAST(CODIGO_ANTIGO AS NUMERIC);

    UPDATE ITEM_PREVENDA SET PROCOD = CAST(CODIGO_NOVO AS VARCHAR) WHERE PROCOD = CAST(CODIGO_ANTIGO AS VARCHAR) ;

   
    -- Adiciona o novo produto na fila do PANAMA
    INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, IDENTIFICADOR, PRIORIDADE, BODY, OPERACAO, ENTIDADE_ID, OBJETO_ID, ORIGEM)
    SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'PRODUTO', 0, TO_JSON(PRODUTOS), 'ATUALIZACAO', PRODUTOS.id, PRODUTOS.id, 'SCRIPT'
      FROM (SELECT P.PROCOD::TEXT AS "id"
                 , UPPER(P.PRODES) AS "descricao"
                 , UPPER(P.PROFIN) AS "finalidade"
                 , CASE WHEN P.PROPESVAR = 'S' THEN true WHEN P.PROPESVAR = 'P' THEN true WHEN P.PROPESVAR = 'D' THEN true ELSE false END AS "pesoVariavel"
                 , P.PROITEEMBVDA "quantidadeItensEmbalagem"
                 , SG.SGPID::TEXT AS "subgrupoId"
                 , G.GRPID::TEXT AS "grupoId"
                 , S.SECID::TEXT AS "secaoId"
                 , CASE WHEN P.PROCOMP = 'C' AND EXISTS(SELECT 1 FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) THEN 'COMPOSTO' WHEN P.PROCOMP = 'K' AND EXISTS(SELECT 1 FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) THEN 'KIT' ELSE CASE WHEN P.PROCOMP = 'R' THEN 'RENDIMENTO' ELSE 'NORMAL' END END AS "tipoComposicao"
                 , CASE WHEN (P.PROCOMP = 'C' OR P.PROCOMP = 'K') AND EXISTS(SELECT 1 FROM COMPOSICAO C WHERE C.COMP_PROCOD = P.PROCOD) THEN (SELECT TO_JSON(COMPOSICAO) FROM (SELECT (SELECT COALESCE(C.COMP_QUANTIDADE, 1) FROM composicao C where C.COMP_PROCOD = P.PROCOD) AS "quantidade", JSON_AGG(COMPONENTES) AS "itens" FROM (SELECT CC.CC_PROCOD::TEXT AS "produtoId", CC.CC_QUANTIDADE AS "quantidade" FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) COMPONENTES) COMPOSICAO) ELSE null END AS "composicao"
              FROM PRODUTO P
              JOIN SECAO S ON (S.SECCOD = P.SECCOD)
              LEFT JOIN GRUPO_PRODUTO G ON (G.GRPCOD = P.GRPCOD AND G.SECCOD = P.SECCOD)
              LEFT JOIN SUBGRUPO_PRODUTO SG ON (SG.SGPCOD = P.SGPCOD AND SG.GRPCOD = P.GRPCOD AND SG.SECCOD = P.SECCOD)
             WHERE PROCOD = CODIGO_NOVO
             GROUP BY P.PROCOD, P.PRODES, P.PROFIN, P.PROPESVAR, P.PROITEEMBVDA, SG.SGPID, G.GRPID, S.SECID, P.PROCOMP) PRODUTOS
    ;

    -- Apaga as informações da estatistica de movimentação de produto
    DELETE FROM ESTATISTICA_PRODUTO_MOVIMENTACAO ;

    -- Apaga o produto antigo da demais produtos que não estão listadas na lista de UPDATEs
    FOR NOME_TABELA, NOME_COLUNA IN
    SELECT C.RELNAME, A.ATTNAME
      FROM PG_CLASS AS C
     INNER JOIN PG_ATTRIBUTE AS A ON (A.ATTRELID = C.OID)
     WHERE (UPPER(A.ATTNAME) IN (UPPER('PROCOD'), UPPER('CODIGO_PRODUTO'), UPPER('ID_PRODUTO'), UPPER('RES_CODIGO_PRODUTO'))
        OR  UPPER(A.ATTNAME) LIKE UPPER('%_PROCOD'))
       AND UPPER(C.RELKIND) = 'R'
       AND UPPER(C.RELNAME) NOT IN ('PG_PROC', 'PG_OPERATOR', 'PG_AMPROC', 'PG_CONVERSION', 'PG_SECLABEL', 'PG_SHSECLABEL', 'SQL_LANGUAGES', 'SQL_SIZING_PROFILES',
                                    'PRODUTO', 'ESTATISTICA_PRODUTO_VENDA', 'ESTATISTICA_PRODUTO_COMPRA', 'ASSISTENTE_COMPRA_PRODUTO', 'ASSISTENTE_COMPRA_ITEM',
                                    'ALTERACAO_PRODUTO_SPED', 'BI_VENDAS', 'DETALHE_CONFIGURACAO_COMISSAO', 'ITEM_NOTA_FISCAL', 'ITEM_NOTA_FISCAL_BKP', 'ITEM_INVENTARIO',
                                    'ITEM_AJUSTE_ESTOQUE', 'ITEM_PRODUCAO_COMPOSICAO', 'ITEM_VENDA', 'ITEM_TRANSFERENCIA', 'ITEM_NOTA_DEVOLUCAO', 'ITEM_PEDIDO_COMPRA', 'ITEM_PEDIDO_VENDA',
                                    'ITEM_PREVENDA_ECOMMERCE', 'PRODUTO_ESTOQUE', 'PREMIO', 'PRODUCAO_COMPOSICAO', 'PRODUTO_SUGESTAO_COMPRA', 'PROMOCAO_PREMIACAO_PROD',
                                    'REGIME_PRODUTO_LOJA', 'RENDIMENTO_PRODUTO', 'ESTOQUE_MOVIMENTACAO', 'COMISSAO', 'CONFIGURACAO_COMISSAO', 'ITEM_DEVOLUCAO_CUPOM', 'CONFERENCIA_PRODUTO',
                                    'RESGATE_NETPOINTS', 'ITEM_PREVENDA', 'ESTOQUE_DIA', 'ESTOQUE_RESUMO')
    LOOP
        EXECUTE 'DELETE FROM ' || NOME_TABELA || ' WHERE ' || NOME_COLUNA || ' = ' || CAST(CODIGO_ANTIGO AS VARCHAR) ;
    END LOOP;
    

    -- Habilita novamente todas as constrants das tabelas
    -- PERFORM HABILITA_OU_DESABILITA_CONSTRANTS(TRUE) ;

    -- Atualiza a movimentação de estoque após o ajuste das demais tabelas.
    INSERT INTO ESTOQUE_MOVIMENTACAO
    SELECT NEXTVAL('SQ_MOVIMENTACAO_ESTOQUE')
         , CODIGO_NOVO
         , EM.LOJ_CODIGO
         , EM.LOC_CODIGO
         , EM.MOV_QUANTIDADE
         , EM.MOV_DATA
         , EM.MOV_DATA_REGISTRO
         , EM.MOV_TIPO
         , EM.ETA_CODIGO
         , EM.MOV_HISTORICO
         , EM.MOV_COMPLEMENTO
         , EM.ID_REDIMENTO_PMP
         , EM.ID_REDIMENTO_RP
         , EM.PCO_ID
         , EM.IPC_ID
         , EM.ITN_ID
         , EM.ID_ITEM_VENDA
         , EM.ITT_ID
         , EM.IAE_ID
         , EM.IIVT_ID
         , EM.DEVOLUCAO_ID
         , EM.FUN_CODIGO 
      FROM ESTOQUE_MOVIMENTACAO EM
     WHERE EM.PROCOD = CODIGO_ANTIGO
    ;

    UPDATE ESTOQUE_MOVIMENTACAO SET IIVT_ID = NULL WHERE PROCOD = CODIGO_ANTIGO ;
    UPDATE ESTOQUE_MOVIMENTACAO SET IIVT_ID = NULL WHERE MOV_ID IN (SELECT MOV_ID FROM ITEM_INVENTARIO WHERE PROCOD = CODIGO_ANTIGO) ;

    UPDATE ITEM_INVENTARIO SET MOV_ID = NULL WHERE PROCOD = CODIGO_ANTIGO ;
    UPDATE ITEM_INVENTARIO SET MOV_ID = NULL WHERE MOV_ID IN (SELECT MOV_ID FROM ESTOQUE_MOVIMENTACAO WHERE PROCOD = CODIGO_ANTIGO) ;

    DELETE FROM ESTOQUE_MOVIMENTACAO WHERE PROCOD = CODIGO_ANTIGO ;

     -- Ajuste dos itens do inventario
    SELECT COUNT(IVT_ID)
      INTO INVENTARIOS_COM_OS_2_PRODUTOS
      FROM (SELECT IVT_ID
              FROM ITEM_INVENTARIO
             WHERE PROCOD IN (CODIGO_ANTIGO, CODIGO_NOVO)
             GROUP BY IVT_ID
            HAVING COUNT(PROCOD) > 1) T1
    ;

    IF INVENTARIOS_COM_OS_2_PRODUTOS > 0 THEN
        UPDATE ITEM_INVENTARIO IV
           SET IIVT_PRIMEIRA_DIGITACAO = IV.IIVT_PRIMEIRA_DIGITACAO + IV2.IIVT_PRIMEIRA_DIGITACAO
             , IIVT_SEGUNDA_DIGITACAO = IV.IIVT_SEGUNDA_DIGITACAO + IV2.IIVT_SEGUNDA_DIGITACAO
             , IIVT_TERCEIRA_DIGITACAO = IV.IIVT_TERCEIRA_DIGITACAO + IV2.IIVT_TERCEIRA_DIGITACAO
             , IIVT_SALDO = IV.IIVT_SALDO + IV2.IIVT_SALDO
          FROM ITEM_INVENTARIO IV2
         WHERE IV.PROCOD = CODIGO_NOVO
           AND IV2.PROCOD = CODIGO_ANTIGO
           AND IV.IVT_ID = IV2.IVT_ID
           AND IV.IVT_ID IN (SELECT IVT_ID
                               FROM ITEM_INVENTARIO
                              WHERE PROCOD IN (CODIGO_ANTIGO, CODIGO_NOVO)
                              GROUP BY IVT_ID
                             HAVING COUNT(PROCOD) > 1)
        ;

        DELETE
          FROM ITEM_INVENTARIO
         WHERE PROCOD = CODIGO_ANTIGO
        ;
    END IF;

    UPDATE ITEM_INVENTARIO SET PROCOD = CODIGO_NOVO WHERE PROCOD = CODIGO_ANTIGO ;

    -- Marca o produto antigo como excluido
    UPDATE PRODUTO SET PRODUTO_DESTINO = CODIGO_NOVO WHERE PROCOD = CODIGO_ANTIGO ;

    -- Reprocessa as estatisticas de compra
    PERFORM REPROCESSAR_ESTATISTICA_COMPRA() ;

    -- Reprocessa as estatisticas de movimentação
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW())) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW())) AS INT)) ;
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW() - INTERVAL '1 MONTHS')) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW() - INTERVAL '1 MONTHS')) AS INT)) ;
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW() - INTERVAL '2 MONTHS')) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW() - INTERVAL '2 MONTHS')) AS INT)) ;
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW() - INTERVAL '3 MONTHS')) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW() - INTERVAL '3 MONTHS')) AS INT)) ;
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW() - INTERVAL '4 MONTHS')) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW() - INTERVAL '4 MONTHS')) AS INT)) ;
    PERFORM REPROCESSAR_ESTATISTICA_MOVIMENTACAO(CAST(EXTRACT(MONTH FROM (SELECT NOW() - INTERVAL '5 MONTHS')) AS INT), CAST(EXTRACT(YEAR FROM (SELECT NOW() - INTERVAL '5 MONTHS')) AS INT)) ;

    -- Reprocessa a venda consolidada
    PERFORM REPROCESSAR_VENDA_CONSOLIDADA_A_PARTIR_DE(CAST('2010-01-01' AS DATE)) ;

    -- Atualiza as informações do produto no PANAMA
    INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, IDENTIFICADOR, PRIORIDADE, ENTIDADE_ID, OPERACAO, OBJETO_ID, ORIGEM)
    SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'VENDA', 2, VENDA.id, 'EXCLUSAO', VENDA.id, 'SCRIPT'
      FROM (SELECT T.TRNSEQ::TEXT||'-'||T.CXANUM::TEXT||'-'||T.LOJCOD::TEXT||'-'||TO_CHAR(T.TRNDAT, 'yyyy-MM-dd') AS "id"
              FROM TRANSACAO T
              JOIN ITEM_VENDA I ON (T.TRNSEQ = I.TRNSEQ 
                               AND  T.LOJCOD = I.LOJCOD 
                               AND  T.TRNDAT = I.TRNDAT 
                               AND  T.CXANUM = I.CXANUM)
     WHERE I.PROCOD = CODIGO_ANTIGO
       AND T.TRNDAT BETWEEN '2013-01-01' AND CURRENT_DATE) VENDA
    ;

    INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, IDENTIFICADOR, PRIORIDADE, ENTIDADE_ID, OPERACAO, OBJETO_ID, ORIGEM)
    SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'VENDA', 2, VENDA.id, 'EXCLUSAO', VENDA.id, 'SCRIPT'
      FROM (SELECT NF.NTA_CODIGO || '-' || NF.LOJ_CODIGO || '-' || TO_CHAR(NF.NTA_DATA_EMISSAO,'YYYY-MM-DD') AS "id"
              FROM NOTA_FISCAL NF
              JOIN ITEM_NOTA_FISCAL I ON (I.NTA_CODIGO = NF.NTA_CODIGO)
             WHERE NF.NTA_CLASSIFICACAO = 'VENDA'
               AND I.PROCOD = CODIGO_ANTIGO
               AND NF.NTA_DATA_EMISSAO BETWEEN '2013-01-01' AND CURRENT_DATE) VENDA
    ;

    INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, IDENTIFICADOR, PRIORIDADE, BODY, OPERACAO, ENTIDADE_ID, OBJETO_ID, ORIGEM)
    (SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'VENDA', 2, TO_JSON(VENDAS), 'ATUALIZACAO', VENDAS.id, VENDAS.id, 'SCRIPT'
       FROM (SELECT T.TRNSEQ::TEXT||'-'||T.CXANUM::TEXT||'-'||T.LOJCOD::TEXT||'-'||TO_CHAR(T.TRNDAT, 'yyyy-MM-dd') AS "id"
                  , T.TRNSEQ::TEXT AS "sequencial"
                  , T.CXANUM::TEXT AS "numeroCaixa"
                  , T.LOJCOD::TEXT AS "lojaId"
                  , T.TRNDAT AS "data"
                  , COALESCE(T.TRNHORFIN, COALESCE(T.TRNHORINI, COALESCE(T.TRNDATVEN, T.TRNDAT))) AS "dataHoraVenda"
                  , FUN.FUN_CODIGO::TEXT AS "funcionarioId"
                  , C.CLI_CODIGO::TEXT AS "clienteId"
                  , true AS "efetiva"
                  , T.TRNTIPPRC::TEXT AS "tipoPreco"
                  , T.TRNTDCCOD::TEXT AS "tipoDesconto"
                  , T.TRNVLR AS "valor"
                  , T.TRNACR AS "acrescimo"
                  , T.TRNDCN AS "desconto"
                  , T.TRNVLRSER AS "servico"
                  , COALESCE(T.TRNQTDITEVDA, (SELECT COUNT(IV.ID) 
                                                FROM ITEM_VENDA IV 
                                               WHERE T.TRNSEQ = IV.TRNSEQ 
                                                 AND T.LOJCOD = IV.LOJCOD 
                                                 AND T.TRNDAT = IV.TRNDAT 
                                                 AND T.CXANUM = IV.CXANUM 
                                                 AND IV.ITVTIP = '1' 
                                                 AND IV.ITVVLRUNI > 0)) AS "quantidadeItens"
                  , COALESCE(T.TRNQTDITECAN, (SELECT COUNT(IV.ID) 
                                                FROM ITEM_VENDA IV 
                                               WHERE T.TRNSEQ = IV.TRNSEQ 
                                                 AND T.LOJCOD = IV.LOJCOD 
                                                 AND T.TRNDAT = IV.TRNDAT 
                                                 AND T.CXANUM = IV.CXANUM 
                                                 AND IV.ITVTIP = '2')) AS "quantidadeItensCancelados"
                  , COALESCE(T.TRNVLRITECAN, (SELECT SUM(IV.ITVVLRTOT) 
                                                FROM ITEM_VENDA IV 
                                               WHERE T.TRNSEQ = IV.TRNSEQ 
                                                 AND T.LOJCOD = IV.LOJCOD 
                                                 AND T.TRNDAT = IV.TRNDAT 
                                                 AND T.CXANUM = IV.CXANUM 
                                                 AND IV.ITVTIP = '2')) AS "valorItensCancelados"
                  , (SELECT JSON_AGG(ITENS) 
                       FROM (SELECT CAST(CODIGO_NOVO AS VARCHAR) AS "produtoId"
                                  , IV.FUNCOD::TEXT AS "funcionarioId"
                                  , true AS "efetivo"
                                  , IV.ITVQTDVDA AS "quantidade"
                                  , IV.ITVVLRUNI AS "valorUnitario"
                                  , IV.ITVVLRTOT AS "valorTotal"
                                  , IV.ITVVLRACR AS "acrescimo"
                                  , IV.ITVVLRDCN AS "desconto"
                                  , COALESCE(IV.ITVPRCVDA, IV.ITVVLRTOT/IV.ITVQTDVDA) AS "preco"
                                  , IV.ITVVLRSER AS "servico"
                                  , IV.ITVTIPPRC::TEXT AS "tipoPreco"
                               FROM ITEM_VENDA IV 
                              WHERE T.TRNSEQ = IV.TRNSEQ 
                                AND T.LOJCOD = IV.LOJCOD 
                                AND T.TRNDAT = IV.TRNDAT 
                                AND T.CXANUM = IV.CXANUM 
                                AND IV.ITVTIP = '1' 
                                AND IV.ITVVLRUNI > 0) ITENS) AS "itens"
                  , (SELECT JSON_AGG(FIN) 
                       FROM (SELECT F.FZCSEQ::TEXT AS "sequencial"
                                  , F.FZDCOD::TEXT AS "formaPagamentoId"
                                  , F.FZCVLR - COALESCE(F.FZCCTRVAL, 0) AS "valor"
                               FROM FINALIZACAO F 
                              WHERE F.TRNDAT = T.TRNDAT 
                                AND F.LOJCOD = T.LOJCOD 
                                AND F.TRNSEQ = T.TRNSEQ 
                                AND F.CXANUM = T.CXANUM) FIN) AS "pagamentos"
               FROM TRANSACAO T
               JOIN ITEM_VENDA I ON (T.TRNSEQ = I.TRNSEQ 
                                AND  T.LOJCOD = I.LOJCOD 
                                AND  T.TRNDAT = I.TRNDAT 
                                AND  T.CXANUM = I.CXANUM)
               JOIN FINALIZACAO F ON (T.TRNSEQ = F.TRNSEQ
                                 AND  T.LOJCOD = F.LOJCOD 
                                 AND  T.TRNDAT = F.TRNDAT 
                                 AND  T.CXANUM = F.CXANUM) 
               LEFT JOIN PESSOA_CLIENTE C ON (T.CLICOD = C.CLI_CODIGO) 
               LEFT JOIN PESSOA_FUNCIONARIO FUN ON (T.FUNCOD = FUN.FUN_CODIGO) 
              WHERE T.TRNDAT BETWEEN '2013-01-01' AND CURRENT_DATE
                AND T.TRNTIP = '1'
                AND I.ITVTIP = '1'
                AND I.ITVVLRUNI > 0
                AND I.PROCOD = CODIGO_NOVO
              GROUP BY T.TRNSEQ, T.LOJCOD, T.TRNDAT, T.CXANUM, C.CLI_CODIGO, FUN.FUN_CODIGO) VENDAS)
    ;

    INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, IDENTIFICADOR, PRIORIDADE, BODY, OPERACAO, ENTIDADE_ID, OBJETO_ID, ORIGEM)
    SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'VENDA', 2, TO_JSON(VENDAS), 'ATUALIZACAO', VENDAS.id, VENDAS.id, 'SCRIPT'
      FROM (SELECT NF.NTA_CODIGO || '-' || NF.LOJ_CODIGO || '-' || TO_CHAR(NF.NTA_DATA_EMISSAO,'YYYY-MM-DD') AS "id"
                 , NF.NTA_CODIGO AS "sequencial"
                 , NF.LOJ_CODIGO AS "lojaId"
                 , TO_CHAR(NF.NTA_DATA_EMISSAO,'YYYY-MM-DD') AS "data"
                 , TO_CHAR(NF.NTA_DATA_EMISSAO,'YYYY-MM-DD') AS "dataHoraVenda"
                 , NTA_FUNCIONARIO_CADASTROU AS "funcionarioId"
                 , (SELECT CLI_CODIGO FROM PESSOA_CLIENTE JOIN PESSOA ON PESSOA_CLIENTE.PES_CODIGO = PESSOA.PES_CODIGO WHERE PESSOA_CLIENTE.PES_CODIGO = NF.PES_CODIGO) AS "clienteId"
                 , true AS "efetiva"
                 , '1' AS "tipoPreco"
                 , 'V' AS "tipoDesconto"
                 , NF.NTA_VALOR AS "valor"
                 , NF.NTA_TOTAL_VALOR_OUTRAS AS "acrescimo"
                 , NF.NTA_TOTAL_VALOR_DESCONTO AS "desconto"
                 , 0 AS "servico"
                 , (SELECT COUNT(ITEM_NOTA_FISCAL.ITN_ID) FROM ITEM_NOTA_FISCAL WHERE ITEM_NOTA_FISCAL.NTA_CODIGO = NF.NTA_CODIGO) AS "quantidadeItens"
                 , 0 AS "quantidadeItensCancelados"
                 , 0 AS "valorItensCancelados"
                 , (SELECT JSON_AGG(ITENS)
                      FROM (SELECT ITEM.PROCOD AS "produtoId"
                                 , ITEM.NTA_FUNCIONARIO_COMPRADOR AS "funcionarioId"
                                 , true AS "efetivo"
                                 , ITEM.ITN_QUANTIDADE_COMPLETA AS "quantidade"
                                 , ITEM.VALOR_UNITARIO AS "valorUnitario"
                                 , ITEM.VALOR_TOTAL AS "valorTotal"
                                 , ITEM.ITN_VALOR_OUTRAS_DESPESAS AS "acrescimo"
                                 , ITEM.ITN_VALOR_DESCONTO AS "desconto"
                                 , ITEM.VALOR_UNITARIO AS "preco"
                                 , 0 AS "servico"
                                 , '1' AS "tipoPreco"
                              FROM (SELECT IINF.PROCOD
                                         , INF.NTA_FUNCIONARIO_COMPRADOR
                                         , IINF.ITN_QUANTIDADE_COMPLETA
                                         , CASE WHEN IINF.ITN_QUANTIDADE_COMPLETA > 0
                                             THEN ROUND((COALESCE(IINF.ITN_VALOR_TOTAL, 0)
                                         +               COALESCE(IINF.ITN_VALOR_FRETE, 0)
                                         +               COALESCE(IINF.ITN_VALOR_OUTRAS_DESPESAS, 0)
                                         +               COALESCE(IINF.ITN_VALOR_SEGURO, 0)
                                         +               COALESCE(IINF.ITN_VALOR_IPI, 0)
                                         +               COALESCE(IINF.ITN_VALOR_ICMSST, 0)
                                         +               COALESCE(IINF.ITN_VALOR_ICMS_DESONERADO, 0)
                                         -               COALESCE(IINF.ITN_VALOR_DESCONTO, 0))
                                         /              IINF.ITN_QUANTIDADE_COMPLETA, 2)
                                             ELSE 0
                                           END AS VALOR_UNITARIO
                                         , ROUND((COALESCE(IINF.ITN_VALOR_TOTAL, 0)
                                         +        COALESCE(IINF.ITN_VALOR_FRETE, 0)
                                         +        COALESCE(IINF.ITN_VALOR_OUTRAS_DESPESAS, 0)
                                         +        COALESCE(IINF.ITN_VALOR_SEGURO, 0)
                                         +        COALESCE(IINF.ITN_VALOR_IPI, 0)
                                         +        COALESCE(IINF.ITN_VALOR_ICMSST, 0)
                                         +        COALESCE(IINF.ITN_VALOR_ICMS_DESONERADO, 0)
                                         -        COALESCE(IINF.ITN_VALOR_DESCONTO, 0)), 2) AS VALOR_TOTAL
                                         , COALESCE(IINF.ITN_VALOR_OUTRAS_DESPESAS, 0) AS ITN_VALOR_OUTRAS_DESPESAS
                                         , COALESCE(IINF.ITN_VALOR_DESCONTO, 0) AS ITN_VALOR_DESCONTO
                                      FROM NOTA_FISCAL INF
                                      JOIN ITEM_NOTA_FISCAL IINF ON IINF.NTA_CODIGO = INF.NTA_CODIGO
                                     WHERE INF.NTA_CODIGO = NF.NTA_CODIGO
                                       AND IINF.ITN_COMPOE_TOTAL_NOTA_FISCAL = true) ITEM) ITENS) AS "itens"
                 , (SELECT JSON_AGG(PAGAMENTO)
                      FROM (SELECT COALESCE(FF.FZDCOD::TEXT, 'VIRTUAL') AS "formaPagamentoId"
                                 , '001' AS "sequencial"
                                 , FNF.NTA_VALOR AS "valor"
                              FROM NOTA_FISCAL FNF
                              LEFT JOIN CONTA_A_RECEBER FCR ON FCR.CTR_ID = FNF.CTR_ID 
                              LEFT JOIN ESPECIE_DOCUMENTO FED ON FED.EDC_CODIGO = FCR.EDC_CODIGO 
                              LEFT JOIN FINALIZADORA FF ON FF.EDC_CODIGO = FED.EDC_CODIGO 
                             WHERE FNF.NTA_CODIGO = NF.NTA_CODIGO) PAGAMENTO) AS "pagamentos"
              FROM NOTA_FISCAL NF
             INNER JOIN ITEM_NOTA_FISCAL INF ON (INF.NTA_CODIGO = NF.NTA_CODIGO)
             WHERE NF.NTA_CLASSIFICACAO = 'VENDA'
               AND NF.NTA_TIPO_OPERACAO = 'SAIDA'
               AND NF.NTA_MODALIDADE = 'NORMAL'
               AND NF.NTA_SITUACAO = 'EFETIVADA'
               AND NF.NTA_COMPOE_ABC = true
               AND NF.NTA_DATA_EMISSAO BETWEEN '2018-09-01' AND CURRENT_DATE
               AND INF.PROCOD = CODIGO_NOVO) VENDAS
    ;

END
$BODY$
LANGUAGE 'plpgsql' ;
