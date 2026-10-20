-- SELECT AlteraCodigoProdutoSemPassarCodigoAntigo(789621710898980, descobre_proximo_codigo) ;
-- SELECT AlteraCodigoProdutoSemPassarCodigoAntigo() ;
-- DROP FUNCTION AlteraCodigoProdutoSemPassarCodigoAntigo() ;
CREATE OR REPLACE FUNCTION public.AlteraCodigoProdutoSemPassarCodigoAntigo() RETURNS VOID AS
$BODY$
DECLARE
    codigo_antigo bigint;
    codigo_novo bigint;
    
    BEGIN
        CREATE TABLE temp_prod AS SELECT PROCOD FROM PRODUTO WHERE procod > 9999999 AND proenvbal = 'N' ;
        -- CREATE TABLE temp_prod AS SELECT PROCOD FROM PRODUTO WHERE procod > 99999999 AND proenvbal = 'N' ;
        
        RAISE NOTICE 'DESABILITANDO TRIGGER ESTOQUE_MOVIMENTACAO' ;
        DROP TRIGGER estoque_movimentacao_trigger ON public.estoque_movimentacao;

        RAISE NOTICE 'DESABILITANDO AS CONSTRAINT' ;
        ALTER TABLE public.custo_dia DROP CONSTRAINT fk_custo_dia_produto ;
        ALTER TABLE public.estoque_resumo DROP CONSTRAINT fk_r_produto ;
        ALTER TABLE public.estatistica_produto_compra DROP CONSTRAINT fk_epc_produto ;
        ALTER TABLE public.estatistica_produto_movimentacao DROP CONSTRAINT fk_epm_produto ;
        ALTER TABLE public.estatistica_produto_venda DROP CONSTRAINT fk_epv_produto ;
        ALTER TABLE public.estoque_dia DROP CONSTRAINT fk_estdia_produto ;
        ALTER TABLE public.estoque_movimentacao DROP CONSTRAINT fk_estoque_produto ;
        ALTER TABLE public.movimentacao_de_custo DROP CONSTRAINT fk_moc_de_custo_produto ;
        ALTER TABLE public.preco DROP CONSTRAINT preco_produto_fk ;
        ALTER TABLE public.composicao DROP CONSTRAINT fk_composicao_produto ;
        ALTER TABLE public.item_venda DROP CONSTRAINT fk_item_venda_produto ;
        ALTER TABLE public.produto_historico DROP CONSTRAINT fk_produto_historico ;
        ALTER TABLE public.produto_familia DROP CONSTRAINT fk_produto_familia_produto ;
        ALTER TABLE public.assistente_compra_produto DROP CONSTRAINT assistente_compra_produto_procod_fkey ;
        ALTER TABLE public.componentes_composicao DROP CONSTRAINT fk_componentes_composicao_produto ;
        ALTER TABLE public.cotacao_preco_produto DROP CONSTRAINT fk_produto ;
        ALTER TABLE public.temp_cotacao_preco_produto DROP CONSTRAINT fk_produto ;
        ALTER TABLE public.assistente_compra_item DROP CONSTRAINT assistente_compra_item_procod_fkey ;
        ALTER TABLE public.programacao_preco DROP CONSTRAINT fk_programacao_produto ;
        ALTER TABLE public.item_ajuste_estoque DROP CONSTRAINT fk_item_ajuste_produto ;
        ALTER TABLE public.impostos_federais_produto DROP CONSTRAINT fk_produto_impfed ;
        -- ALTER TABLE public.produto_loja DROP CONSTRAINT fk_produto_loja_loja ;
        ALTER TABLE public.produto_loja DROP CONSTRAINT fk_produto_loja_produto ;
        ALTER TABLE public.alteracao_preco_em_lote_produto DROP CONSTRAINT fk_alteracao_preco_produto ;

        FOR codigo_antigo IN
          SELECT * FROM temp_prod
          LOOP

            EXECUTE 'SELECT descobre_proximo_codigo()' INTO codigo_novo ;
            RAISE NOTICE '----------------------------------------------' ;
            RAISE NOTICE 'AJUSTANDO PRODUTO DE %', codigo_antigo || ' - ' || codigo_novo ;
            UPDATE alteracao_preco_em_lote_produto  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ALTERACAO_PRODUTO_SPED' ;
            UPDATE alteracao_produto_sped           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA APLICACAO_PRODUTO' ;
            UPDATE aplicacao_produto                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ASSISTENTE_COMPRA_ITEM' ;
            UPDATE assistente_compra_item           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA AUDITORIA_CUSTO' ;
            UPDATE auditoria_custo                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA AUDITORIA_PRECO' ;
            UPDATE auditoria_preco                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA CARACTERISTICA_PRODUTO' ;
            UPDATE caracteristica_produto           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA COMISSAO' ;
            UPDATE comissao                         SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA COMPONENTES_COMPOSICAO' ;
            UPDATE componentes_composicao           SET cc_procod            = codigo_novo WHERE cc_procod            = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA COMPOSICAO' ;
            UPDATE composicao                       SET comp_procod          = codigo_novo WHERE comp_procod          = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA CONFERENCIA_PRODUTO' ;
            UPDATE conferencia_produto              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA CONFIGURACAO_COMISSAO' ;
            UPDATE configuracao_comissao            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA COTACAO_PRECO_RESULTADO' ;
            UPDATE cotacao_preco_resultado          SET cpr_codigo_produto   = codigo_novo WHERE cpr_codigo_produto   = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA DETALHE_CONFIGURACAO_COMISSAO' ;
            UPDATE detalhe_configuracao_comissao    SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ENCARTE_PRODUTO' ;
            UPDATE encarte_produto                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_NOTA_FISCAL' ;
            UPDATE item_nota_fiscal                 SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA VENDA_CONSOLIDADA_PRODUTO' ;
            UPDATE venda_consolidada_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTOQUE' ;
            UPDATE estoque                          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTOQUE_MOVIMENTACAO' ;
            UPDATE estoque_movimentacao             SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTOQUE_RESUMO' ;
            UPDATE estoque_resumo                   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTOQUE_DIA' ;
            UPDATE estoque_dia                      SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA EXPORTACAO_FISCAL' ;
            UPDATE exportacao_fiscal                SET ef_tam_cod_produto   = codigo_novo WHERE ef_tam_cod_produto   = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA HIST_COMPONENTES_COMPOSICAO' ;
            UPDATE hist_componentes_composicao      SET hist_cc_procod       = codigo_novo WHERE hist_cc_procod       = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA HIST_COMPOSICAO' ;
            UPDATE hist_composicao                  SET hist_comp_procod     = codigo_novo WHERE hist_comp_procod     = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA IMPOSTOS_FEDERAIS_PRODUTO' ;
            UPDATE impostos_federais_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_AJUSTE_ESTOQUE' ;
            UPDATE item_ajuste_estoque              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_DEVOLUCAO_CUPOM' ;
            UPDATE item_devolucao_cupom             SET id_produto           = codigo_novo WHERE id_produto           = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_INVENTARIO' ;
            UPDATE item_inventario                  SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_NOTA_DEVOLUCAO' ;
            UPDATE item_nota_devolucao              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_NOTA_FISCAL_BKP' ;
            UPDATE item_nota_fiscal_bkp             SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_PEDIDO_COMPRA' ;
            UPDATE item_pedido_compra               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_PEDIDO_VENDA' ;
            UPDATE item_pedido_venda                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_TRANSFERENCIA' ;
            UPDATE item_transferencia               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ITEM_VENDA' ;
            UPDATE item_venda                       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA MOVIMENTACAO_DE_CUSTO' ;
            UPDATE movimentacao_de_custo            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PAUTA_PRODUTO' ;
            UPDATE pauta_produto                    SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PREMIO' ;
            UPDATE premio                           SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO_HISTORICO' ;
            UPDATE produto_historico                SET prod_hist_procod     = codigo_novo WHERE prod_hist_procod     = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO_FAMILIA' ;
            UPDATE produto_familia                  SET codigo_produto       = codigo_novo WHERE codigo_produto       = codigo_antigo ;
             --RAISE NOTICE 'AJUSTANDO TABELA COTACAO_PRECO_PRODUTO' ;
            UPDATE cotacao_preco_produto            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO' ;
            UPDATE produto                          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ASSISTENTE_COMPRA_PRODUTO' ;
            UPDATE assistente_compra_produto        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO_FORNECEDOR' ;
            UPDATE produto_fornecedor               SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA CUSTO_DIA' ;
            UPDATE custo_dia                        SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUCAO_COMPOSICAO' ;
            UPDATE producao_composicao              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRECO' ;
            UPDATE preco                            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTATISTICA_PRODUTO_COMPRA' ;
            UPDATE estatistica_produto_compra       SET epc_procod           = codigo_novo WHERE epc_procod           = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTATISTICA_PRODUTO_MOVIMENTACAO' ;
            UPDATE estatistica_produto_movimentacao SET epm_procod           = codigo_novo WHERE epm_procod           = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA ESTATISTICA_PRODUTO_VENDA' ;
            UPDATE estatistica_produto_venda        SET epv_procod           = codigo_novo WHERE epv_procod           = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO_SUGESTAO_COMPRA' ;
            UPDATE produto_sugestao_compra          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTOAUX' ;
            UPDATE produtoaux                       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTOS_NCM_SINCRONIZACAO' ;
            UPDATE produtos_ncm_sincronizacao       SET produto              = codigo_novo WHERE produto              = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PROGRAMACAO_PRECO' ;
            UPDATE programacao_preco                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PROMOCAO_DESCONTO' ;
            UPDATE promocao_desconto                SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PROMOCAO_PAGUE_LEVE_ITEM' ;
            UPDATE promocao_pague_leve_item         SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PROMOCAO_PREMIACAO_PROD' ;
            UPDATE promocao_premiacao_prod          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA PRODUTO LOJA' ;
            UPDATE produto_loja                     SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA RECEITA' ;
            --UPDATE receita                          SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA REGIME_PRODUTO_LOJA' ;
            UPDATE regime_produto_loja              SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA RENDIMENTO_PRODUTO' ;
            UPDATE rendimento_produto               SET codigo_produto       = codigo_novo WHERE codigo_produto       = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA REQUISICAO_ITEM_TROCA' ;
            UPDATE requisicao_item_troca            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA REQUISICAO_ITEM_VENDA' ;
            UPDATE requisicao_item_venda            SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA RESGATE_NETPOINTS' ;
            UPDATE resgate_netpoints                SET res_codigo_produto   = codigo_novo WHERE res_codigo_produto   = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA TEMP_COTACAO_PRECO_PRODUTO' ;
            UPDATE temp_cotacao_preco_produto       SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA VENDA_CASADA_PRODUTO_PRINCIPAL' ;
            UPDATE venda_casada_produto_principal   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'AJUSTANDO TABELA VENDA_CASADA_PRODUTO_PROMOCION' ;
            UPDATE venda_casada_produto_promocion   SET procod               = codigo_novo WHERE procod               = codigo_antigo ;
            --RAISE NOTICE 'ALIMENTANTO TABELA PRODUTOAUX' ;
            RAISE NOTICE 'INSERINDO CÓDIGO NA TABELA DE PRODUTOAUX      ' ;
            RAISE NOTICE '----------------------------------------------' ;
            INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
                 VALUES (LPAD(CAST(codigo_antigo AS TEXT), 14, '0')
                       , codigo_novo
                       , 1
                       , 'EAN'
--                       , cast(substring(CAST(codigo_antigo AS CHAR(14)) FROM 0 FOR 13) as INT8)
                       , CAST(SUBSTR(CAST(codigo_antigo AS TEXT), 1, LENGTH(CAST(codigo_antigo AS TEXT)) - 1) AS BIGINT)
                       , true
                       , true)
            ;

--            UPDATE produtoaux SET proauxcodigoean = CAST(SUBSTRING(procodaux FROM 0 FOR 14) AS int8) WHERE procod = codigo_novo ;
       END LOOP;
       DROP TABLE temp_prod ;
       RAISE NOTICE '' ;
       RAISE NOTICE 'HABILITANDO AS CONSTRAINT' ;
       ALTER TABLE public.produto_loja ADD CONSTRAINT fk_produto_loja_produto FOREIGN KEY (procod) REFERENCES produto(procod) ON DELETE CASCADE ; 
       -- ALTER TABLE public.produto_loja ADD CONSTRAINT fk_produto_loja_loja FOREIGN KEY (loj_codigo) REFERENCES public.pessoa_loja(loj_codigo) ON DELETE CASCADE ;
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
       ALTER TABLE public.alteracao_preco_em_lote_produto ADD CONSTRAINT fk_alteracao_preco_produto FOREIGN KEY (procod) REFERENCES produto(procod) ON DELETE CASCADE ;


       RAISE NOTICE '' ;
       RAISE NOTICE 'HABILITANDO TRIGGER ESTOQUE_MOVIMENTACAO' ;
       CREATE TRIGGER estoque_movimentacao_trigger
         AFTER INSERT OR UPDATE OR DELETE
         ON public.estoque_movimentacao
         FOR EACH ROW
         EXECUTE PROCEDURE public.processa_estoque();
       
     --   RAISE NOTICE 'DELETANDO AUXILIARES COM MAIS DE 20 CARACTERES' ;
     --   DELETE
     --     FROM produtoaux
     --    WHERE procodaux ~* '^[0-9]*$'
     --      AND CHAR_LENGTH(procodaux) > 20 ;
     --   RAISE NOTICE '' ;

     --   RAISE NOTICE 'DELETANDO AUXILIARES SEM GTIN' ;
     --   DELETE 
     --     FROM produtoaux
     --    WHERE procodaux LIKE '%SEM GTIN%' ;
     --   RAISE NOTICE '' ;

     --   RAISE NOTICE 'DELETANDO AUXILIARES CASO SEJA IGUAL AO PROCOD' ;
     --   DELETE
     --     FROM produtoaux 
     --    WHERE CAST(procodaux AS BIGINT) IN (SELECT procod 
     --                                               FROM produto) 
     --      AND proauxtipo = 'EAN' ;
     --   RAISE NOTICE '' ;

     --   RAISE NOTICE 'TRANSFORMAR EM LITERAL OS EANS INVALIDOS' ;
     --   UPDATE produtoaux 
     --      SET proauxtipo = 'LITERAL'
     --        , proauxcodigoean = NULL
     --        , proeantrib = false 
     --    WHERE validar_ean(procodaux) = false ;

     --   UPDATE produtoaux 
     --      SET proauxtipo = 'LITERAL'
     --        , proauxcodigoean = NULL
     --        , proeantrib = false 
     --    WHERE validar_gs1(procodaux) = false ;
     --   RAISE NOTICE '' ;

     --   RAISE NOTICE 'DEFININDO COMO TRIBUTADO O EAN' ;
     --   UPDATE produtoaux 
     --      SET proeantrib = true 
     --    WHERE procodaux IN (SELECT DISTINCT ON (procod) procodaux 
     --                          FROM produtoaux 
     --                         WHERE proauxtipo = 'EAN' 
     --                           AND procod NOT IN (SELECT DISTINCT procod 
     --                                                FROM produtoaux 
     --                                               WHERE proauxtipo = 'EAN' 
     --                                                 AND proeantrib IS true) 
     --                         ORDER BY procod
     --                             , proauxfat
     --                             , procodaux) ;
     --   RAISE NOTICE '' ;

     --   RAISE NOTICE 'DEFININDO EAN TRIBUTADO COMO PRINCIPAL' ;
     --   UPDATE produtoaux 
     --      SET proeanprinc = true 
     --    WHERE proeantrib = true ;

     --   UPDATE produtoaux 
     --      SET proeanprinc = true 
     --    WHERE proauxtipo = 'EAN' 
     --      AND procodaux IN (SELECT DISTINCT ON (procod)procodaux 
     --                          FROM produtoaux t1 
     --                         WHERE t1.procod NOT IN (SELECT DISTINCT t1.procod 
     --                                                   FROM produto t1 JOIN produtoaux t2 ON t2.procod = t1.procod 
     --                                                  WHERE proauxtipo = 'EAN' 
     --                                                    AND proeantrib = true)
     --                       ) ;

     --   UPDATE produtoaux 
     --      SET proeanprinc = FALSE 
     --    WHERE proeanprinc IS NULL ;

     --   WITH ean AS (SELECT procod
     --                  FROM   produtoaux p
     --                 GROUP BY procod 
     --                HAVING COUNT(*) > 1)
     -- UPDATE produtoaux aux 
     --    SET proeanprinc = FALSE 
     --   FROM ean
     --  WHERE aux.procod = ean.procod
     --    AND aux.procodaux::BIGINT IN (SELECT codigo_produto_antigo 
     --                                    FROM produto)
     --    AND aux.proeanprinc = TRUE
     --    AND aux.proean;

    END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


  --11:00