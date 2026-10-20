BEGIN ;

DROP TRIGGER estoque_movimentacao_trigger ON public.estoque_movimentacao;

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

UPDATE alteracao_produto_sped SET procod = 10646 WHERE procod = 1 ;
UPDATE aplicacao_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE assistente_compra_item SET procod = 10646 WHERE procod = 1 ;
UPDATE auditoria_custo SET procod = 10646 WHERE procod = 1 ;
UPDATE auditoria_preco SET procod = 10646 WHERE procod = 1 ;
UPDATE caracteristica_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE comissao SET procod = 10646 WHERE procod = 1 ;
UPDATE componentes_composicao SET cc_procod = 10646 WHERE cc_procod = 1 ;
UPDATE composicao SET comp_procod  = 10646 WHERE comp_procod  = 1 ;
UPDATE conferencia_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE configuracao_comissao SET procod = 10646 WHERE procod = 1 ;
UPDATE cotacao_preco_resultado SET cpr_codigo_produto = 10646 WHERE cpr_codigo_produto = 1 ;
UPDATE detalhe_configuracao_comissao SET procod = 10646 WHERE procod = 1 ;
UPDATE encarte_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE item_nota_fiscal SET procod = 10646 WHERE procod = 1 ;
UPDATE venda_consolidada_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE estoque SET procod = 10646 WHERE procod = 1 ;
UPDATE estoque_movimentacao SET procod = 10646 WHERE procod = 1 ;
UPDATE estoque_resumo SET procod = 10646 WHERE procod = 1 ;
UPDATE estoque_dia SET procod = 10646 WHERE procod = 1 ;
UPDATE exportacao_fiscal SET ef_tam_cod_produto = 10646 WHERE ef_tam_cod_produto = 1 ;
UPDATE hist_componentes_composicao SET hist_cc_procod = 10646 WHERE hist_cc_procod = 1 ;
UPDATE hist_composicao SET hist_comp_procod = 10646 WHERE hist_comp_procod = 1 ;
UPDATE impostos_federais_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE item_ajuste_estoque SET procod = 10646 WHERE procod = 1 ;
UPDATE item_devolucao_cupom SET id_produto = 10646 WHERE id_produto = 1 ;
UPDATE item_inventario SET procod = 10646 WHERE procod = 1 ;
UPDATE item_nota_devolucao SET procod = 10646 WHERE procod = 1 ;
UPDATE item_nota_fiscal_bkp SET procod = 10646 WHERE procod = 1 ;
UPDATE item_pedido_compra SET procod = 10646 WHERE procod = 1 ;
UPDATE item_pedido_venda SET procod = 10646 WHERE procod = 1 ;
UPDATE item_transferencia SET procod = 10646 WHERE procod = 1 ;
UPDATE item_venda SET procod = 10646 WHERE procod = 1 ;
UPDATE movimentacao_de_custo SET procod = 10646 WHERE procod = 1 ;
UPDATE pauta_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE premio SET procod = 10646 WHERE procod = 1 ;
UPDATE produto_historico SET prod_hist_procod = 10646 WHERE prod_hist_procod = 1 ;
UPDATE produto_familia SET codigo_produto = 10646 WHERE codigo_produto = 1 ;
UPDATE cotacao_preco_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE produto SET procod = 10646 WHERE procod = 1 ;
UPDATE assistente_compra_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE produto_fornecedor SET procod = 10646 WHERE procod = 1 ;
UPDATE custo_dia SET procod = 10646 WHERE procod = 1 ;
UPDATE producao_composicao SET procod = 10646 WHERE procod = 1 ;
UPDATE preco SET procod = 10646 WHERE procod = 1 ;
UPDATE estatistica_produto_compra SET epc_procod = 10646 WHERE epc_procod = 1 ;
UPDATE estatistica_produto_movimentacao SET epm_procod = 10646 WHERE epm_procod = 1 ;
UPDATE estatistica_produto_venda SET epv_procod = 10646 WHERE epv_procod = 1 ;
UPDATE produto_sugestao_compra SET procod = 10646 WHERE procod = 1 ;
UPDATE produtoaux SET procod = 10646 WHERE procod = 1 ;
UPDATE produtos_ncm_sincronizacao SET produto  = 10646 WHERE produto  = 1 ;
UPDATE programacao_preco SET procod = 10646 WHERE procod = 1 ;
UPDATE promocao_desconto SET procod = 10646 WHERE procod = 1 ;
UPDATE promocao_pague_leve_item SET procod = 10646 WHERE procod = 1 ;
UPDATE promocao_premiacao_prod SET procod = 10646 WHERE procod = 1 ;
UPDATE regime_produto_loja SET procod = 10646 WHERE procod = 1 ;
UPDATE rendimento_produto SET codigo_produto = 10646 WHERE codigo_produto = 1 ;
UPDATE requisicao_item_troca SET procod = 10646 WHERE procod = 1 ;
UPDATE requisicao_item_venda SET procod = 10646 WHERE procod = 1 ;
UPDATE resgate_netpoints SET res_codigo_produto = 10646 WHERE res_codigo_produto = 1 ;
UPDATE temp_cotacao_preco_produto SET procod = 10646 WHERE procod = 1 ;
UPDATE venda_casada_produto_principal SET procod = 10646 WHERE procod = 1 ;
UPDATE venda_casada_produto_promocion SET procod = 10646 WHERE procod = 1 ;

INSERT INTO produtoaux (procodaux, procod, proauxfat, proauxtipo, proauxcodigoean, proeantrib, proeanprinc)
 VALUES ('01'
  , 10646
  , 1
  , 'EAN'
  , 789730120033
  , TRUE
  , TRUE) ;

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

CREATE TRIGGER estoque_movimentacao_trigger
 AFTER INSERT OR UPDATE OR DELETE
 ON public.estoque_movimentacao
 FOR EACH ROW
 EXECUTE PROCEDURE public.processa_estoque();