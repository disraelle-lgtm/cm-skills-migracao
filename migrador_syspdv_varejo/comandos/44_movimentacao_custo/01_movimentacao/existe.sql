-- No Pentaho a chave era o proprio moc_id da sequence (sempre inseria: duplicava a cada execucao).
-- Aqui: um ajuste de custo de migracao por loja + produto.
SELECT moc_id FROM movimentacao_de_custo
 WHERE loj_codigo = %(loj_codigo)s AND procod = %(procod)s AND moc_tipo_movimentacao = 'AJUSTE_CUSTO'
 LIMIT 1
