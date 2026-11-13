-- Pentaho, T-Fornecedor-Pessoa: Insert/Update pelo documento SEM atualizar nada
-- (todos os campos com Update = N) -> se a pessoa ja existe (ex.: tambem e cliente), reaproveita.
WITH existente AS (
    SELECT pes_codigo FROM pessoa
     WHERE pes_num_documento = %(pes_num_documento)s
     ORDER BY pes_codigo LIMIT 1
), nova AS (
    INSERT INTO pessoa (pes_codigo, pes_num_documento, pes_nome, pes_logradouro, pes_bairro
                      , pes_descricao_cidade, pes_uf, pes_telefone1, pes_fax, pes_cep, pes_numero
                      , pes_complemento, pes_fantasia, pes_num_identificacao, pes_email
                      , mcp_codigo_ibge, pes_pais, pes_tipo)
    SELECT nextval('sq_pessoa'), %(pes_num_documento)s, %(pes_nome)s, %(pes_logradouro)s, %(pes_bairro)s
         , %(pes_descricao_cidade)s, %(pes_uf)s, %(pes_telefone1)s, %(pes_fax)s, %(pes_cep)s, %(pes_numero)s
         , %(pes_complemento)s, %(pes_fantasia)s, %(pes_num_identificacao)s, %(pes_email)s
         , %(mcp_codigo_ibge)s, %(pes_pais)s, %(pes_tipo)s
     WHERE NOT EXISTS (SELECT 1 FROM existente)
    RETURNING pes_codigo
)                                                       -- T-Fornecedor-PessoaFornecedor
INSERT INTO pessoa_fornecedor (pes_codigo, for_codigo, for_prazo_entrega, transportadora
                             , destaca_subs_devolucao_compra, for_tipo_fornecedor, ret_codigo
                             , for_considera_desoneracao_como_desconto)
SELECT pes_codigo, %(for_codigo)s, %(for_prazo_entrega)s, %(transportadora)s
     , FALSE, 'VAREJO', %(ret_codigo)s, TRUE
  FROM (SELECT pes_codigo FROM existente UNION ALL SELECT pes_codigo FROM nova) AS p
