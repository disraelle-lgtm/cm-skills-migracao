-- Pentaho: T-MovimentacaoEstoque-CRIA-TIPO-AJUSTE (Data Grid com os 2 tipos; chave eta_codigo,
-- descricao/tipo/tipo reservado com Update = Y)
INSERT INTO estoque_tipo_ajuste (eta_codigo, eta_descricao, eta_tipo, eta_tipo_reservado)
SELECT v.codigo, v.descricao, v.tipo, v.reservado
  FROM (VALUES (9001, 'AJUSTES DE MIGRACAO', 'SAIDA', 'AJUSTE_MIGRACAO'),
               (9002, 'AJUSTES DE MIGRACAO', 'ENTRADA', 'AJUSTE_MIGRACAO')) AS v (codigo, descricao, tipo, reservado)
 WHERE NOT EXISTS (SELECT 1 FROM estoque_tipo_ajuste t WHERE t.eta_codigo = v.codigo);
UPDATE estoque_tipo_ajuste
   SET eta_descricao = 'AJUSTES DE MIGRACAO', eta_tipo = CASE eta_codigo WHEN 9001 THEN 'SAIDA' ELSE 'ENTRADA' END,
       eta_tipo_reservado = 'AJUSTE_MIGRACAO'
 WHERE eta_codigo IN (9001, 9002);

-- Desliga as triggers da tabela produto durante a migracao do estoque (sem isto demora muito).
ALTER TABLE produto DISABLE TRIGGER ALL
