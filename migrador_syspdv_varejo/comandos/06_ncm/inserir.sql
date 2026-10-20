-- Pentaho: "VF - Alimenta Tabela Real e Dropa Temp".
INSERT INTO ncm (ncm_codigo, ncm_descricao, ncm_aliquota_ipi, ncm_ativo, ncm_motivo_inativacao)
VALUES (%(ncm_codigo)s, 'NCM INATIVO', 0, FALSE, 'Atualização de NCM')
