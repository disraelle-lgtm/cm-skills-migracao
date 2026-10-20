DELETE FROM fila_sincronizacao_panama ;

INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'FORMA_PAGAMENTO'
        , '0'
        , TO_JSON(FINALIZADORAS)
        , FINALIZADORAS.id
        , 'ATUALIZACAO'
        , FINALIZADORAS.id
    FROM (SELECT F.FZDCOD::TEXT AS "id",
                 UPPER(F.FZDDES) AS "descricao"
           FROM FINALIZADORA F)
    FINALIZADORAS) ;
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'HOLDING'
        , 0
        , TO_JSON(HOLDINGS)
        , HOLDINGS.id
        , 'ATUALIZACAO'
        , HOLDINGS.id
     FROM (SELECT H.HOLCOD::TEXT AS "id",
                  UPPER(H.HOLDES) AS "descricao"
           FROM HOLDING H)
    HOLDINGS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        ,'MIGRACAO'
        , 'LOJA'
        , 0
        , TO_JSON(LOJAS)
        , LOJAS.id
        , 'ATUALIZACAO'
        , LOJAS.id
     FROM (SELECT L.LOJ_CODIGO::TEXT AS "id",
                  L.LOJ_ATIVO AS "ativa",
                  CASE WHEN L.LOJ_MATRIZ = 'S' THEN true ELSE false END AS "matriz",
                  P.PES_NUM_DOCUMENTO AS "numeroDocumento",
                  UPPER(P.PES_NOME) AS "descricao",
                  P.HOLCOD::TEXT AS "holdingId",
                  UPPER(F.FIG_DESCRICAO) AS "ramo",
                  UPPER(P.PES_UF) AS "uf",
                  UPPER(P.PES_DESCRICAO_CIDADE) AS "cidade",
                  UPPER(P.PES_BAIRRO) AS "bairro"
           FROM PESSOA_LOJA L
           JOIN PESSOA P ON (P.PES_CODIGO = L.PES_CODIGO)
           JOIN FIGURA_FISCAL F ON (F.FIG_CODIGO = L.FIG_CODIGO))
     LOJAS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'FUNCIONARIO'
        , 0
        , TO_JSON(FUNCIONARIOS)
        , FUNCIONARIOS.id
        , 'ATUALIZACAO'
        , FUNCIONARIOS.id
     FROM (SELECT F.FUN_CODIGO::TEXT AS "id",
                  F.FUN_DATA_NASCIMENTO AS "dataNascimento",
                  P.PES_NUM_DOCUMENTO AS "numeroDocumento",
                  UPPER(P.PES_NOME) AS "nome",
                  UPPER(U.USUNOM) AS "login",
                  U.USUSEN AS "senha",
                  COALESCE(U.ATIVO, false) AS "ativo",
                  (SELECT ARRAY(SELECT FL.LOJCOD::TEXT FROM FUNCIONARIO_LOJA FL WHERE FL.FUNCOD = F.FUN_CODIGO AND FL.FLJ_STATUS = 'A')) AS "lojaIds"
                  FROM PESSOA_FUNCIONARIO F
                  JOIN PESSOA P ON (P.PES_CODIGO = F.PES_CODIGO)
                  LEFT JOIN USUARIO U ON (U.FUNCOD = F.FUN_CODIGO)
                  LEFT JOIN FUNCIONARIO_LOJA FL ON (FL.FUNCOD = F.FUN_CODIGO AND FL.FLJ_STATUS = 'A')
                  GROUP BY F.FUN_CODIGO, P.PES_NUM_DOCUMENTO, P.PES_NOME, U.USUNOM, U.USUSEN, U.ATIVO)
    FUNCIONARIOS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'ACESSO'
        , 0
        , TO_JSON(USUARIOS)
        , USUARIOS.id
        , 'ATUALIZACAO'
        , USUARIOS.id
    FROM (SELECT 'PERM_APP_ACESSO' AS "id",
                  ARRAY_AGG(U.FUNCOD::TEXT) AS "funcionarioIds"
           FROM USUARIO U WHERE U.ADMINISTRADOR = true AND U.ATIVO = true)
    USUARIOS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'CLIENTE'
        , 0
        , TO_JSON(CLIENTES)
        , CLIENTES.id
        , 'ATUALIZACAO'
        , CLIENTES.id
     FROM (SELECT C.CLI_CODIGO::TEXT AS "id",
                  UPPER(COALESCE(P.PES_NOME, COALESCE(P.PES_FANTASIA, 'SEM NOME'))) AS "nome",
                  COALESCE(P.PES_NUM_DOCUMENTO, 'SEM DOCUMENTO') AS "numeroDocumento",
                  COALESCE(UPPER(R.RAMDES), (SELECT RAMDES FROM RAMO LIMIT 1)) AS "ramo",
                  COALESCE(UPPER(P.PES_UF), M.PES_UF) AS "uf",
                  COALESCE(UPPER(P.PES_DESCRICAO_CIDADE), M.PES_DESCRICAO_CIDADE) AS "cidade",
                  COALESCE(UPPER(P.PES_BAIRRO), M.PES_BAIRRO) AS "bairro"
           FROM PESSOA_CLIENTE C
           JOIN PESSOA P ON (P.PES_CODIGO = C.PES_CODIGO)
           JOIN RAMO R ON (R.RAMCOD = C.RAMCOD)
           CROSS JOIN (SELECT P.* FROM PESSOA_LOJA L JOIN PESSOA P ON (P.PES_CODIGO = L.PES_CODIGO) WHERE LOJ_MATRIZ = 'S' LIMIT 1) M
           WHERE (P.PES_NOME <> '' OR P.PES_FANTASIA <> '') AND (P.PES_NOME IS NOT NULL OR P.PES_FANTASIA IS NOT NULL))
    CLIENTES);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'SECAO'
        , 0
        , TO_JSON(SECOES)
        , SECOES.id
        , 'ATUALIZACAO'
        , SECOES.id
    FROM (SELECT SECID::TEXT AS "id",
                 SECCOD::TEXT AS "codigo",
                 COALESCE(UPPER(SECDES), 'SEM DESCRIÇÃO') AS "descricao"
           FROM SECAO
           WHERE SECCOD IS NOT NULL)
    SECOES);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'GRUPO'
        , 0
        , TO_JSON(GRUPOS)
        , GRUPOS.id
        , 'ATUALIZACAO'
        , GRUPOS.id
    FROM (SELECT GRPID::TEXT AS "id",
                 GRPCOD::TEXT AS "codigo",
                 COALESCE(UPPER(GRPDES), 'SEM DESCRIÇÃO') AS "descricao",
                 SECCOD::TEXT AS "secaoId"
           FROM GRUPO_PRODUTO
           WHERE GRPCOD IS NOT NULL AND SECCOD IS NOT NULL)
    GRUPOS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'SUBGRUPO'
        , 0
        , TO_JSON(SUBGRUPOS)
        , SUBGRUPOS.id
        , 'ATUALIZACAO'
        , SUBGRUPOS.id
    FROM (SELECT SGPID::TEXT AS "id",
                 SGPCOD::TEXT AS "codigo",
                 COALESCE(UPPER(SGPDES), 'SEM DESCRIÇÃO') AS "descricao",
                 GRPCOD::TEXT AS "grupoId",
                 SECCOD::TEXT AS "secaoId"
           FROM SUBGRUPO_PRODUTO
           WHERE SGPCOD IS NOT NULL AND GRPCOD IS NOT NULL AND SECCOD IS NOT NULL)
    SUBGRUPOS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
(SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
        , 'MIGRACAO'
        , 'PRODUTO'
        , 0
        , TO_JSON(PRODUTOS)
        , PRODUTOS.id
        , 'ATUALIZACAO'
        , PRODUTOS.id
    FROM (SELECT P.PROCOD::TEXT AS "id",
                 UPPER(P.PRODES) AS "descricao",
                 UPPER(P.PROFIN) AS "finalidade",
                 CASE WHEN P.PROPESVAR = 'S' THEN true WHEN P.PROPESVAR = 'P' THEN true WHEN P.PROPESVAR = 'D' THEN true ELSE false END AS "pesoVariavel",
                 P.PROITEEMBVDA "quantidadeItensEmbalagem",
                 SG.SGPID::TEXT AS "subgrupoId",
                 G.GRPID::TEXT AS "grupoId",
                 S.SECID::TEXT AS "secaoId",
                 CASE WHEN P.PROCOMP = 'C' AND EXISTS(SELECT 1 FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) THEN 'COMPOSTO' WHEN P.PROCOMP = 'K' AND EXISTS(SELECT 1 FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) THEN 'KIT' ELSE CASE WHEN P.PROCOMP = 'R' THEN 'RENDIMENTO' ELSE 'NORMAL' END END AS "tipoComposicao",
                 CASE WHEN (P.PROCOMP = 'C' OR P.PROCOMP = 'K') AND EXISTS(SELECT 1 FROM COMPOSICAO C WHERE C.COMP_PROCOD = P.PROCOD) THEN (SELECT TO_JSON(COMPOSICAO) FROM (SELECT (SELECT COALESCE(C.COMP_QUANTIDADE, 1) FROM composicao C where C.COMP_PROCOD = P.PROCOD) AS "quantidade", JSON_AGG(COMPONENTES) AS "itens" FROM (SELECT CC.CC_PROCOD::TEXT AS "produtoId", CC.CC_QUANTIDADE AS "quantidade" FROM COMPONENTES_COMPOSICAO CC JOIN COMPOSICAO C ON (CC.CC_COMP_ID = C.COMP_ID) WHERE C.COMP_PROCOD = P.PROCOD) COMPONENTES) COMPOSICAO) ELSE null END AS "composicao"
            FROM PRODUTO P
            JOIN SECAO S ON (S.SECCOD = P.SECCOD)
            LEFT JOIN GRUPO_PRODUTO G ON (G.GRPCOD = P.GRPCOD AND G.SECCOD = P.SECCOD)
            LEFT JOIN SUBGRUPO_PRODUTO SG ON (SG.SGPCOD = P.SGPCOD AND SG.GRPCOD = P.GRPCOD AND SG.SECCOD = P.SECCOD)
            GROUP BY P.PROCOD, P.PRODES, P.PROFIN, P.PROPESVAR, P.PROITEEMBVDA, SG.SGPID, G.GRPID, S.SECID, P.PROCOMP)
    PRODUTOS);
INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, ENTIDADE_ID, OPERACAO, OBJETO_ID)
    (SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA')
    , 'MIGRACAO'
    , 'EAN'
    , 0
    , TO_JSON(AUXILIARES)
    , AUXILIARES.id
    , 'ATUALIZACAO'
    , AUXILIARES.id
     FROM (SELECT UPPER(PROCODAUX)::TEXT AS "id",
                  PROCOD::TEXT AS "produtoId"
           FROM PRODUTOAUX)
    AUXILIARES);

INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, OPERACAO, OBJETO_ID)
     SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'MIGRACAO', 'TITULO_PAGAR', 0, TO_JSON(TITULOS), 'ATUALIZACAO', TITULOS.ID
       FROM ( SELECT T.TTLP_ID::TEXT "id"
                   , T.LOJ_CODIGO::TEXT "lojaId"
                   , T.FOR_CODIGO::TEXT "fornecedorId"
                   , T.CTP_NUM_DOCUMENTO "documento"
                   , T.TTLP_VALOR "valorNominal"
                   , T.CTP_DATA_EMISSAO AS "dataEmissao"
                   , T.TTLP_VENCIMENTO "dataVencimento"
                   , COALESCE(T.TTLP_TOTAL_JUROS_PAGO, 0) "valorJuros"
                   , COALESCE(T.TTLP_TOTAL_MULTA_PAGA, 0) "valorMulta"
                   , COALESCE(T.TTLP_TOTAL_PAGO, 0) "valorPago"
                   , T.PGTOS AS "pagamentos"
                   , T.TTLP_SALDO + ROUND(COALESCE( CASE WHEN CTP_MODALIDADE = 'S' AND CTP_TIPO_VALOR_MORA_DIARIA = 'VALOR' THEN DIAS_JUROS * CTP_MORA_DIARIA_ATRASO
                                               WHEN CTP_MODALIDADE = 'S' AND CTP_TIPO_VALOR_MORA_DIARIA = 'PERCENTUAL' THEN DIAS_JUROS * T.TTLP_SALDO * ROUND(CTP_MORA_DIARIA_ATRASO/100, 6)
                                               WHEN CTP_MODALIDADE != 'S' THEN (T.TTLP_SALDO * POW(1 + ROUND(CTP_MORA_DIARIA_ATRASO/100, 6), DIAS_JUROS)) - T.TTLP_SALDO
                                               END, 0)::NUMERIC, 2) + ROUND(COALESCE(CASE WHEN DIAS_MULTA > 0 AND T.TTLP_TOTAL_MULTA_PAGA = 0 AND CTP_TIPO_VALOR_MULTA = 'VALOR' THEN CTP_VALOR_MULTA_POR_ATRASO
                                                                                          WHEN DIAS_MULTA > 0 AND T.TTLP_TOTAL_MULTA_PAGA = 0 AND CTP_TIPO_VALOR_MULTA = 'PERCENTUAL' THEN T.TTLP_SALDO * ROUND(CTP_VALOR_MULTA_POR_ATRASO/100, 6)
                                                                                          ELSE 0 END, 0)::NUMERIC, 2) as "valorDevido"
                FROM (SELECT T.TTLP_ID
                           , T.TTLP_VALOR
                           , T.TTLP_SALDO
                           , T.TTLP_ULTIMO_PAGAMENTO
                           , T.TTLP_STATUS
                           , C.CTP_MORA_DIARIA_ATRASO
                           , C.CTP_TIPO_VALOR_MORA_DIARIA
                           , C.CTP_MODALIDADE
                           , C.CTP_DIAS_INCIDENCIA_MULTA
                           , C.CTP_DIAS_INCIDENCIA_JUROS
                           , C.CTP_VALOR_MULTA_POR_ATRASO
                           , C.CTP_TIPO_VALOR_MULTA
                           , T.TTLP_TOTAL_MULTA_PAGA
                           , T.TTLP_TOTAL_JUROS_PAGO
                           , T.TTLP_TOTAL_PAGO
                           , T.TTLP_TOTAL_ACRESCIMO
                           , T.TTLP_TOTAL_DESCONTO
                           , T.TTLP_TOTAL_AMORTIZADO
                           , C.LOJ_CODIGO
                           , C.FOR_CODIGO
                           , C.CTP_NUM_DOCUMENTO
                           , T.TTLP_VENCIMENTO
                           , C.CTP_DATA_EMISSAO
                           , GREATEST(CASE WHEN TTLP_STATUS != 'RENEGOCIADO' THEN DATE_PART('DAY', NOW() - COALESCE(TTLP_ULTIMO_PAGAMENTO, T.TTLP_VENCIMENTO + concat(CTP_DIAS_INCIDENCIA_JUROS, ' days')::interval)) end, 0) DIAS_JUROS
                           , GREATEST(CASE WHEN TTLP_STATUS != 'RENEGOCIADO' THEN DATE_PART('DAY', NOW() - T.TTLP_VENCIMENTO) end, 0) DIAS_MULTA
                           , COALESCE((SELECT JSON_AGG(ITENS)
                                         FROM (SELECT M.MOV_DATA "dataHora"
                                                    , MOV_VALOR "valor"
                                                 FROM MOVIMENTACAO_TITULO_PAGAR M
                                                WHERE M.TTLP_ID = T.TTLP_ID
                                                  AND M.MOV_OPERACAO IN ('LIQUIDACAO_DE_TITULO', 'LIQUIDACAO_DE_TITULO_E_PENDENTE', 'LIQUIDADO_PARCIALMENTE', 'LIQUIDADO_PARCIALMENTE_E_PENDENTE')
                                               EXCEPT
                                               SELECT M.MOV_DATA "dataHora"
                                                    , MOV_VALOR "valor"
                                                 FROM MOVIMENTACAO_TITULO_PAGAR M
                                                WHERE M.TTLP_ID = T.TTLP_ID
                                                  AND M.MOV_OPERACAO = 'ESTORNO_DE_TITULO') ITENS ), '[]'::json)  PGTOS
                        FROM TITULO_A_PAGAR T
                        JOIN CONTA_A_PAGAR C ON T.CTP_ID = C.CTP_ID
                       WHERE C.CTP_DATA_EMISSAO >= '2017-08-01'
                         AND T.TTLP_STATUS NOT IN ('CANCELADO', 'EXCLUIDO', 'RENEGOCIADO')) T ) TITULOS ; 

INSERT INTO FILA_SINCRONIZACAO_PANAMA (ID, ORIGEM, IDENTIFICADOR, PRIORIDADE, BODY, OPERACAO, OBJETO_ID)
     SELECT NEXTVAL('SQ_FILA_SINCRONIZACAO_PANAMA'), 'MIGRACAO', 'TITULO_RECEBER', 0, TO_JSON(TITULOS), 'ATUALIZACAO', TITULOS.ID
     FROM ( SELECT T.TTLR_ID::TEXT "id", T.LOJ_CODIGO::TEXT "lojaId", T.CLI_CODIGO::TEXT "clienteId", T.CTR_NUM_DOCUMENTO "documento", T.TTLR_VALOR "valorNominal", T.CTR_DATA_EMISSAO as "dataEmissao", T.TTLR_VENCIMENTO "dataVencimento"
                 , COALESCE(T.TTLR_TOTAL_JUROS_PAGO, 0) "valorJuros"
                 , COALESCE(T.TTLR_TOTAL_MULTA_PAGA, 0) "valorMulta"
                 , COALESCE(T.TTLR_TOTAL_PAGO, 0) "valorPago"
                 , T.PGTOS as "pagamentos"
                 , T.TTLR_SALDO + ROUND(COALESCE( CASE WHEN CTR_MODALIDADE = 'S' AND CTR_TIPO_VALOR_MORA_DIARIA = 'VALOR' THEN DIAS_JUROS * CTR_MORA_DIARIA_ATRASO
                                                       WHEN CTR_MODALIDADE = 'S' AND CTR_TIPO_VALOR_MORA_DIARIA = 'PERCENTUAL' THEN DIAS_JUROS * T.TTLR_SALDO * ROUND(CTR_MORA_DIARIA_ATRASO/100, 6)
                                                       WHEN CTR_MODALIDADE != 'S' THEN (T.TTLR_SALDO * POW(1 + ROUND(CTR_MORA_DIARIA_ATRASO/100, 6), DIAS_JUROS)) - T.TTLR_SALDO
                                                       END, 0)::NUMERIC, 2) +  ROUND(COALESCE(CASE WHEN DIAS_MULTA > 0 AND T.TTLR_TOTAL_MULTA_PAGA = 0 AND CTR_TIPO_VALOR_MULTA = 'VALOR' THEN CTR_VALOR_MULTA_POR_ATRASO
                                                                                                  WHEN DIAS_MULTA > 0 AND T.TTLR_TOTAL_MULTA_PAGA = 0 AND CTR_TIPO_VALOR_MULTA = 'PERCENTUAL' THEN T.TTLR_SALDO * ROUND(CTR_VALOR_MULTA_POR_ATRASO/100, 6)
                                                                                                  ELSE 0 END, 0)::NUMERIC, 2) as "valorDevido"
              FROM (SELECT T.TTLR_ID
                         , T.TTLR_VALOR
                         , T.TTLR_SALDO
                         , T.TTLR_ULTIMO_PAGAMENTO
                         , T.TTLR_STATUS
                         , C.CTR_MORA_DIARIA_ATRASO
                         , C.CTR_TIPO_VALOR_MORA_DIARIA
                         , C.CTR_MODALIDADE
                         , C.CTR_DIAS_INCIDENCIA_MULTA
                         , C.CTR_DIAS_INCIDENCIA_JUROS
                         , C.CTR_VALOR_MULTA_POR_ATRASO
                         , C.CTR_TIPO_VALOR_MULTA
                         , T.TTLR_TOTAL_MULTA_PAGA
                         , T.TTLR_TOTAL_JUROS_PAGO
                         , T.TTLR_TOTAL_PAGO
                         , T.TTLR_TOTAL_ACRESCIMO
                         , T.TTLR_TOTAL_DESCONTO
                         , T.TTLR_TOTAL_AMORTIZADO
                         , C.LOJ_CODIGO
                         , C.CLI_CODIGO
                         , C.CTR_NUM_DOCUMENTO
                         , T.TTLR_VENCIMENTO
                         , C.CTR_DATA_EMISSAO
                         , GREATEST(CASE WHEN TTLR_STATUS != 'RENEGOCIADO' THEN DATE_PART('DAY', NOW() - COALESCE(TTLR_ULTIMO_PAGAMENTO, T.TTLR_VENCIMENTO + concat(CTR_DIAS_INCIDENCIA_JUROS, ' days')::interval)) end, 0) DIAS_JUROS
                         , GREATEST(CASE WHEN TTLR_STATUS != 'RENEGOCIADO' THEN DATE_PART('DAY', NOW() - T.TTLR_VENCIMENTO) END, 0) DIAS_MULTA
                         , COALESCE((SELECT JSON_AGG(ITENS)
                                       FROM (SELECT M.MOV_DATA "dataHora"
                                                  , MOV_VALOR "valor"
                                               FROM MOVIMENTACAO_TITULO_RECEBER M
                                              WHERE M.TTLR_ID = T.TTLR_ID
                                                AND M.MOV_OPERACAO IN ('LIQUIDACAO_DE_TITULO', 'LIQUIDACAO_DE_TITULO_E_PENDENTE', 'LIQUIDADO_PARCIALMENTE', 'LIQUIDADO_PARCIALMENTE_E_PENDENTE')
                                             EXCEPT
                                             SELECT M.MOV_DATA "dataHora"
                                                  , MOV_VALOR "valor"
                                               FROM MOVIMENTACAO_TITULO_RECEBER M
                                              WHERE M.TTLR_ID = T.TTLR_ID
                                                AND M.MOV_OPERACAO = 'ESTORNO_DE_TITULO') ITENS ), '[]'::json) PGTOS
                      FROM TITULO_A_RECEBER T
                      JOIN CONTA_A_RECEBER C ON T.CTR_ID = C.CTR_ID
                     WHERE C.CTR_DATA_EMISSAO >= '2017-08-01'
                       AND C.CTR_ORIGEM_DOCUMENTO != 'CARTAO_CREDITO'
                       AND T.TTLR_STATUS NOT IN ('CANCELADO', 'EXCLUIDO')) T ) TITULOS ;