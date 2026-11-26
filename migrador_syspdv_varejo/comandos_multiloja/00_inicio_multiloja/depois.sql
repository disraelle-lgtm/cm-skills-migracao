-- Tabela de VINCULO da migracao multi loja: para cada loja adicional, qual codigo do SysPDV daquela loja virou qual
-- codigo no VarejoFacil (funcionario, cliente, fornecedor, produto...). novo = criado por esta loja (TRUE) ou ja
-- existia na matriz e so foi ligado (FALSE). Fica num schema separado; pode ser removida no fim do projeto.
CREATE SCHEMA IF NOT EXISTS migracao_multiloja;
CREATE TABLE IF NOT EXISTS migracao_multiloja.vinculo (
    loj_codigo    bigint      NOT NULL,
    tipo          varchar(20) NOT NULL,
    codigo_origem varchar(60) NOT NULL,
    codigo_vf     bigint      NOT NULL,
    novo          boolean     NOT NULL DEFAULT FALSE,
    criado_em     timestamp   NOT NULL DEFAULT now(),
    PRIMARY KEY (loj_codigo, tipo, codigo_origem)
);
CREATE INDEX IF NOT EXISTS ix_vinculo_tipo_vf ON migracao_multiloja.vinculo (tipo, codigo_vf);

-- Codigos de barras de cada produto do SysPDV da loja adicional e o produto do VarejoFacil que tem o mesmo codigo
-- (procod_vf, calculado em bloco no fim da etapa Codigos de barras do item Produto).
CREATE TABLE IF NOT EXISTS migracao_multiloja.produto_ean (
    loj_codigo    bigint      NOT NULL,
    procod_origem varchar(20) NOT NULL,
    ean           varchar(20) NOT NULL,
    procod_vf     bigint,
    PRIMARY KEY (loj_codigo, procod_origem, ean)
);
