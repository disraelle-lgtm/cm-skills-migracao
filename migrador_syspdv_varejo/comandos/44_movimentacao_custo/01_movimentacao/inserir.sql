-- ATENCAO: igual ao Pentaho, moc_custo_medio recebe o CUSTO FISCAL (no custo_dia vai o custo medio).
INSERT INTO movimentacao_de_custo (moc_id, loj_codigo, procod, moc_data, moc_data_registro, moc_estoque_atual,
                                   moc_quantidade, moc_custo_fiscal, moc_custo_reposicao, moc_custo_medio,
                                   moc_custo_medio_ant, moc_tipo_movimentacao, moc_codigo_origem, moc_versao)
VALUES (nextval('sq_movimentacao_custo'), %(loj_codigo)s, %(procod)s, %(data)s, %(data)s, 0,
        0, %(custo_fiscal)s, %(custo_reposicao)s, %(custo_fiscal)s,
        0, 'AJUSTE_CUSTO', 0, 0)
