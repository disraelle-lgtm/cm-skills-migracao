\echo '=========================================='
\echo '🔧 ETAPA 1: CRIANDO CAMPO TEMPORÁRIO...'
\echo '=========================================='

ALTER TABLE produto ADD COLUMN IF NOT EXISTS codigo_produto_antigo int8;

\echo '✅ Campo "codigo_produto_antigo" criado com sucesso!'
\echo ''
\echo '=========================================='
\echo '💾 ETAPA 2: SALVANDO OS CÓDIGOS ATUAIS...'
\echo '=========================================='

UPDATE produto SET codigo_produto_antigo = procod;

\echo '✅ Códigos antigos salvos com sucesso!'
\echo ''
\echo '==================================================='
\echo '🔧 ETAPA 3: CRIANDO FUNÇÃO DESCOBRE CODIGO VAGO...'
\echo '==================================================='

-- Devolve o MENOR código livre entre codigo_minimo e codigo_maximo.
--   * até 10000 ficam reservados para a balança (não são usados como código novo)
--   * >= 999999 são os EAN no código principal, que serão trocados
-- "Livre" = não usado como procod e nem como código auxiliar numérico (produtoaux).
CREATE OR REPLACE FUNCTION public.descobre_proximo_codigo()
    RETURNS BIGINT AS
$BODY$
DECLARE
    codigo_minimo  CONSTANT BIGINT := 10001;      -- primeiro código novo possível
    codigo_maximo  CONSTANT BIGINT := 999998;     -- último (999999+ é EAN)
    proximo_codigo BIGINT;
BEGIN
    WITH usados AS (
        SELECT procod AS codigo
          FROM produto
         WHERE procod BETWEEN codigo_minimo AND codigo_maximo
        UNION
        SELECT CAST(procodaux AS BIGINT)
          FROM produtoaux
         WHERE procodaux ~ '^[0-9]+$'
           AND CHAR_LENGTH(procodaux) < 15
           AND CAST(procodaux AS BIGINT) BETWEEN codigo_minimo AND codigo_maximo
    )
    SELECT CASE
             WHEN NOT EXISTS (SELECT 1 FROM usados WHERE codigo = codigo_minimo) THEN codigo_minimo
             ELSE (SELECT MIN(u.codigo + 1)
                     FROM usados u
                    WHERE NOT EXISTS (SELECT 1 FROM usados u2 WHERE u2.codigo = u.codigo + 1))
           END
      INTO proximo_codigo;

    -- segurança: nunca devolve um código fora da faixa permitida
    IF proximo_codigo IS NULL OR proximo_codigo > codigo_maximo THEN
        RAISE EXCEPTION 'Não há código de produto livre entre % e %', codigo_minimo, codigo_maximo;
    END IF;

    RETURN proximo_codigo;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

\echo '✅ Criado função Descobre Codigo Vago com sucesso!'
\echo ''
\echo '==================================================='
\echo '🔧 ETAPA 4: CRIANDO FUNÇÃO ALTERA CODIGO PRODUTO...'
\echo '==================================================='

CREATE OR REPLACE FUNCTION public.AlteraCodigoProdutoSemPassarCodigoAntigo() RETURNS VOID AS
$BODY$
DECLARE
    codigo_antigo bigint;
    codigo_novo bigint;

    BEGIN
        -- só os produtos com código >= 999999 (EAN no código principal), exceto balança
        CREATE TABLE temp_prod AS SELECT PROCOD FROM PRODUTO WHERE procod >= 999999 AND proenvbal = 'N' ORDER BY procod ;

        DROP TRIGGER estoque_movimentacao_trigger ON public.estoque_movimentacao;

        ALTER TABLE public.custo_dia DROP CONSTRAINT IF EXISTS fk_custo_dia_produto ;
        ALTER TABLE public.produto_sem_inconsistencia DROP CONSTRAINT IF EXISTS produto_sem_inconsistencia_procod_fkey ;
        -- versões antigas deste script criavam esta constraint por engano em impostos_federais_produto
        ALTER TABLE public.impostos_federais_produto DROP CONSTRAINT IF EXISTS produto_sem_inconsistencia_procod_fkey ;
        ALTER TABLE public.estoque_resumo DROP CONSTRAINT IF EXISTS fk_r_produto ;
        ALTER TABLE public.estatistica_produto_compra DROP CONSTRAINT IF EXISTS fk_epc_produto ;
        ALTER TABLE public.estatistica_produto_movimentacao DROP CONSTRAINT IF EXISTS fk_epm_produto ;
        ALTER TABLE public.estatistica_produto_venda DROP CONSTRAINT IF EXISTS fk_epv_produto ;
        ALTER TABLE public.estoque_dia DROP CONSTRAINT IF EXISTS fk_estdia_produto ;
        ALTER TABLE public.estoque_movimentacao DROP CONSTRAINT IF EXISTS fk_estoque_produto ;
        ALTER TABLE public.movimentacao_de_custo DROP CONSTRAINT IF EXISTS fk_moc_de_custo_produto ;
        ALTER TABLE public.preco DROP CONSTRAINT IF EXISTS preco_produto_fk ;
        ALTER TABLE public.composicao DROP CONSTRAINT IF EXISTS fk_composicao_produto ;
        ALTER TABLE public.item_venda DROP CONSTRAINT IF EXISTS fk_item_venda_produto ;
        ALTER TABLE public.produto_historico DROP CONSTRAINT IF EXISTS fk_produto_historico ;
        ALTER TABLE public.produto_familia DROP CONSTRAINT IF EXISTS fk_produto_familia_produto ;
        ALTER TABLE public.assistente_compra_produto DROP CONSTRAINT IF EXISTS assistente_compra_produto_procod_fkey ;
        ALTER TABLE public.componentes_composicao DROP CONSTRAINT IF EXISTS fk_componentes_composicao_produto ;
        ALTER TABLE public.cotacao_preco_produto DROP CONSTRAINT IF EXISTS fk_produto ;
        ALTER TABLE public.temp_cotacao_preco_produto DROP CONSTRAINT IF EXISTS fk_produto ;
        ALTER TABLE public.assistente_compra_item DROP CONSTRAINT IF EXISTS assistente_compra_item_procod_fkey ;
        ALTER TABLE public.programacao_preco DROP CONSTRAINT IF EXISTS fk_programacao_produto ;
        ALTER TABLE public.item_ajuste_estoque DROP CONSTRAINT IF EXISTS fk_item_ajuste_produto ;
        ALTER TABLE public.impostos_federais_produto DROP CONSTRAINT IF EXISTS fk_produto_impfed ;
        ALTER TABLE public.produto_loja DROP CONSTRAINT IF EXISTS fk_produto_loja_produto ;
        ALTER TABLE public.cenario_fiscal_produto_produto DROP CONSTRAINT cenario_fiscal_produto_produto_fk_produto;

        FOR codigo_antigo IN
          SELECT * FROM temp_prod
          LOOP

            EXECUTE 'SELECT descobre_proximo_codigo()' INTO codigo_novo ;
            RAISE NOTICE '----------------------------------------------' ;
            RAISE NOTICE 'AJUSTANDO PRODUTO DE %', codigo_antigo || ' - ' || codigo_novo ;
            UPDATE alteracao_produto_sped           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produto_sem_inconsistencia       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE aplicacao_produto                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE assistente_compra_item           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE auditoria_custo                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE auditoria_preco                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE caracteristica_produto           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE comissao                         SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE componentes_composicao           SET cc_procod            = codigo_novo WHERE cc_procod            = codigo_antigo ;
            UPDATE composicao                       SET comp_procod          = codigo_novo WHERE comp_procod          = codigo_antigo ;
            UPDATE conferencia_produto              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE configuracao_comissao            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE cotacao_preco_resultado          SET cpr_codigo_produto   = codigo_novo WHERE cpr_codigo_produto   = codigo_antigo ;
            UPDATE detalhe_configuracao_comissao    SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE encarte_produto                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_nota_fiscal                 SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE venda_consolidada_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE estoque                          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE estoque_movimentacao             SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE estoque_resumo                   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE estoque_dia                      SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE exportacao_fiscal                SET ef_tam_cod_produto   = codigo_novo WHERE ef_tam_cod_produto   = codigo_antigo ;
            UPDATE hist_componentes_composicao      SET hist_cc_procod       = codigo_novo WHERE hist_cc_procod       = codigo_antigo ;
            UPDATE hist_composicao                  SET hist_comp_procod     = codigo_novo WHERE hist_comp_procod     = codigo_antigo ;
            UPDATE item_ajuste_estoque              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_devolucao_cupom             SET id_produto           = codigo_novo WHERE id_produto           = codigo_antigo ;
            UPDATE item_inventario                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_nota_devolucao              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_nota_fiscal_bkp             SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_pedido_compra               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_pedido_venda                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_transferencia               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE item_venda                       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE movimentacao_de_custo            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE pauta_produto                    SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE premio                           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produto_historico                SET prod_hist_procod     = codigo_novo WHERE prod_hist_procod     = codigo_antigo ;
            UPDATE produto_familia                  SET codigo_produto       = codigo_novo WHERE codigo_produto       = codigo_antigo ;
            UPDATE cotacao_preco_produto            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produto                          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE impostos_federais_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE assistente_compra_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produto_fornecedor               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE custo_dia                        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE producao_composicao              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE preco                            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE estatistica_produto_compra       SET epc_procod           = codigo_novo WHERE epc_procod           = codigo_antigo ;
            UPDATE estatistica_produto_movimentacao SET epm_procod           = codigo_novo WHERE epm_procod           = codigo_antigo ;
            UPDATE estatistica_produto_venda        SET epv_procod           = codigo_novo WHERE epv_procod           = codigo_antigo ;
            UPDATE produto_sugestao_compra          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produtoaux                       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produtos_ncm_sincronizacao       SET produto              = codigo_novo WHERE produto              = codigo_antigo ;
            UPDATE programacao_preco                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE promocao_desconto                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE promocao_pague_leve_item         SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE promocao_premiacao_prod          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE produto_loja                     SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --UPDATE receita                        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE regime_produto_loja              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE rendimento_produto               SET codigo_produto       = codigo_novo WHERE codigo_produto       = codigo_antigo ;
            UPDATE requisicao_item_troca            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE requisicao_item_venda            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE resgate_netpoints                SET res_codigo_produto   = codigo_novo WHERE res_codigo_produto   = codigo_antigo ;
            UPDATE temp_cotacao_preco_produto       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE venda_casada_produto_principal   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE venda_casada_produto_promocion   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            UPDATE cenario_fiscal_produto_produto   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;

            INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
                 VALUES (LPAD(CAST(codigo_antigo AS TEXT), 14, '0')
                       , codigo_novo
                       , 1
                       , 'EAN'
                       , CAST(SUBSTR(CAST(codigo_antigo AS TEXT), 1, LENGTH(CAST(codigo_antigo AS TEXT)) - 1) AS BIGINT)
                       , true
                       , true)
            ;
       END LOOP;
       DROP TABLE temp_prod ;

       ALTER TABLE public.produto_loja ADD CONSTRAINT fk_produto_loja_produto FOREIGN KEY (procod) REFERENCES produto(procod) ON DELETE CASCADE ;
       ALTER TABLE public.custo_dia ADD CONSTRAINT fk_custo_dia_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.estoque_resumo ADD CONSTRAINT fk_r_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.estoque_dia ADD CONSTRAINT fk_estdia_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.estoque_movimentacao ADD CONSTRAINT fk_estoque_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.estatistica_produto_compra ADD CONSTRAINT fk_epc_produto FOREIGN KEY (epc_procod) REFERENCES produto(procod) ON DELETE CASCADE ;
       ALTER TABLE public.estatistica_produto_movimentacao ADD CONSTRAINT fk_epm_produto FOREIGN KEY (epm_procod) REFERENCES produto(procod) ON DELETE CASCADE ;
       ALTER TABLE public.estatistica_produto_venda ADD CONSTRAINT fk_epv_produto FOREIGN KEY (epv_procod) REFERENCES produto(procod) ON DELETE CASCADE ;
       ALTER TABLE public.movimentacao_de_custo ADD CONSTRAINT fk_moc_de_custo_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.preco ADD CONSTRAINT preco_produto_fk FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.composicao ADD CONSTRAINT fk_composicao_produto FOREIGN KEY (comp_procod) REFERENCES produto(procod) ;
       ALTER TABLE public.item_venda ADD CONSTRAINT fk_item_venda_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.produto_historico ADD CONSTRAINT fk_produto_historico FOREIGN KEY (prod_hist_procod) REFERENCES produto(procod) ;
       ALTER TABLE public.produto_familia ADD CONSTRAINT fk_produto_familia_produto FOREIGN KEY (codigo_produto) REFERENCES produto(procod) ;
       ALTER TABLE public.assistente_compra_produto ADD CONSTRAINT assistente_compra_produto_procod_fkey FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.componentes_composicao ADD CONSTRAINT fk_componentes_composicao_produto FOREIGN KEY (cc_procod) REFERENCES produto(procod) ;
       ALTER TABLE public.cotacao_preco_produto ADD CONSTRAINT fk_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.temp_cotacao_preco_produto ADD CONSTRAINT fk_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.assistente_compra_item ADD CONSTRAINT assistente_compra_item_procod_fkey FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.programacao_preco ADD CONSTRAINT fk_programacao_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.item_ajuste_estoque ADD CONSTRAINT fk_item_ajuste_produto FOREIGN KEY (procod) REFERENCES produto(procod) ;
       ALTER TABLE public.impostos_federais_produto ADD CONSTRAINT fk_produto_impfed FOREIGN KEY (procod) REFERENCES produto(procod) ON UPDATE CASCADE ON DELETE CASCADE ;
       ALTER TABLE public.produto_sem_inconsistencia ADD CONSTRAINT produto_sem_inconsistencia_procod_fkey FOREIGN KEY (procod) REFERENCES produto(procod) ON DELETE CASCADE ;
       ALTER TABLE public.cenario_fiscal_produto_produto ADD CONSTRAINT cenario_fiscal_produto_produto_fk_produto FOREIGN KEY (procod) REFERENCES produto(procod);

       CREATE TRIGGER estoque_movimentacao_trigger
         AFTER INSERT OR UPDATE OR DELETE
         ON public.estoque_movimentacao
         FOR EACH ROW
         EXECUTE PROCEDURE public.processa_estoque();

       -- (bloco comentado de limpeza de EAN do original removido; a limpeza real é a ETAPA 8)
    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

\echo '✅ Criado função Alterar Codigo Produto com sucesso!'
\echo ''
\echo '==================================================='
\echo '🔧 ETAPA 5: DESABILITANDO TRIGGER TABELA PRODUTO...'
\echo '==================================================='

alter table produto disable trigger all;

\echo '✅ Trigger desabilitado com sucesso!'
\echo ''
\echo '============================================'
\echo '🔧 ETAPA 6: DELETANDO TABELA PRODUTO LOJA...'
\echo '============================================'

DELETE FROM produto_loja;

\set ON_ERROR_STOP on

\echo '✅ Delete produto_loja com sucesso!'
\echo ''
\echo '======================================================'
\echo '🔧 ETAPA 7: EXECUTANDO FUNÇÃO ALTERA CODIGO PRODUTO...'
\echo '   (produtos com código >= 999999, exceto balança; novos códigos de 10001 a 999998)'
\echo '======================================================'

SELECT AlteraCodigoProdutoSemPassarCodigoAntigo();

\echo '✅ Alteração código produto com sucesso!'
\echo ''
\echo '======================================='
\echo '🔧 ETAPA 8: EXECUTA SCRIPT LIMPA_EAN...'
\echo '======================================='

update produtoaux set proeantrib = false, proeanprinc = false;

DELETE
    FROM produtoaux
WHERE cast(procodaux AS BIGINT) IN (SELECT procod FROM produto)
   AND proauxtipo = 'EAN' ;

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

\echo '✅ Script Limpa_EAN com sucesso!'
\echo ''
\echo '==============================================='
\echo '🔧 ETAPA 9: HABILITA TRIGGERS TABELA PRODUTO...'
\echo '==============================================='

alter table produto enable trigger all;

\echo '✅ Triggers habilitados com sucesso!'
\echo ''
\echo '===================================================='
\echo '🔧 ETAPA 10: MANTÉM AS ALTERAÇÕES ANTERIORES DA ALTERACAO_PRODUTO_SPED...'
\echo '===================================================='

-- Não apaga mais a tabela: as alterações de trocas anteriores ficam guardadas.
-- A etapa 11 grava só os produtos trocados NESTA execução (a etapa 2 deixou
-- codigo_produto_antigo = procod para todos; só os trocados agora ficam diferentes).
SELECT COUNT(*) AS "Alterações anteriores mantidas" FROM alteracao_produto_sped;

\echo ''
\echo '============================================================='
\echo '🔧 ETAPA 11: INSERE DADOS NA TABELA ALTERACAO_PRODUTO_SPED...'
\echo '============================================================='

INSERT INTO alteracao_produto_sped (aps_codigo, procod, aps_data_inicial, aps_data_final, aps_descricao_anterior, aps_procod_anterior, loj_codigo)
SELECT NEXTVAL('sq_alt_produto_sped')
    , procod
    , prodatcadinc
    , prodatcadalt
    , ''
    , codigo_produto_antigo
    , 1
FROM produto
WHERE codigo_produto_antigo != procod
AND codigo_produto_antigo IS NOT NULL
ORDER BY procod ;

-- a data de exportação é gravada depois do INSERT (dentro do INSERT ela não ficava gravada)
-- só nas linhas desta troca: as anteriores não são mexidas
UPDATE alteracao_produto_sped aps
   SET aps_data_exportacao = CURRENT_DATE
  FROM produto p
 WHERE aps.procod = p.procod
   AND aps.aps_procod_anterior = p.codigo_produto_antigo
   AND p.codigo_produto_antigo != p.procod
   AND aps.aps_data_exportacao IS NULL;

\echo '✅ Insert Alteracao_produto_sped com sucesso!'
\echo ''
\echo '============================================================='
\echo '🔧 ETAPA 12: DROPA AS FUNCTION CRIADAS...'
\echo '============================================================='

DROP FUNCTION IF EXISTS descobre_proximo_codigo();
DROP FUNCTION IF EXISTS AlteraCodigoProdutoSemPassarCodigoAntigo();
