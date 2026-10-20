-- DESABILITANDO AS TRIGGER'S DA TABELA PRODUTO PARA ACELERAR A MIGRAÇÃO

--DESABILITAR
-- ALTER TABLE produto DISABLE TRIGGER produto_trigger_upsert ;
ALTER TABLE produto DISABLE TRIGGER produto_trigger_carga_pdx_update ;
ALTER TABLE produto DISABLE TRIGGER trigger_produto_update_secao ;
ALTER TABLE produto DISABLE TRIGGER atualizacao_produto_trigger_mix_update ;
ALTER TABLE produto DISABLE TRIGGER produto_trigger_carga_api_update ;
ALTER TABLE produto DISABLE TRIGGER produto_trigger_carga_api_insert ;
ALTER TABLE produto DISABLE TRIGGER atualizacao_produto_trigger_mix_insert ;
ALTER TABLE produto DISABLE TRIGGER produto_trigger_carga_pdx_insert ;

--HABILITAR
-- ALTER TABLE produto ENABLE TRIGGER produto_trigger_upsert ;
ALTER TABLE produto ENABLE TRIGGER produto_trigger_carga_pdx_update ;
ALTER TABLE produto ENABLE TRIGGER trigger_produto_update_secao ;
ALTER TABLE produto ENABLE TRIGGER atualizacao_produto_trigger_mix_update ;
ALTER TABLE produto ENABLE TRIGGER produto_trigger_carga_api_update ;
ALTER TABLE produto ENABLE TRIGGER produto_trigger_carga_api_insert ;
ALTER TABLE produto ENABLE TRIGGER atualizacao_produto_trigger_mix_insert ;
ALTER TABLE produto ENABLE TRIGGER produto_trigger_carga_pdx_insert ;