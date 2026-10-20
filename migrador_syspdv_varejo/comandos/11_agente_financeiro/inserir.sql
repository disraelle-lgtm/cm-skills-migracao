-- T-Agente-Pessoa: com CNPJ/CPF, Insert/Update pelo documento SEM atualizar nada (Update = N)
--   -> se a pessoa ja existe (cliente, fornecedor...), reaproveita. Sem documento: pessoa nova.
WITH existente AS (
    SELECT pes_codigo FROM pessoa
     WHERE %(pes_num_documento)s::text IS NOT NULL
       AND pes_num_documento = %(pes_num_documento)s::text
     ORDER BY pes_codigo LIMIT 1
), nova AS (
    INSERT INTO pessoa (pes_codigo, pes_tipo, pes_num_documento, pes_nome, pes_fantasia, pes_uf
                      , pes_logradouro, pes_numero, pes_bairro, pes_descricao_cidade, pes_telefone1
                      , pes_fax, pes_email)
    SELECT nextval('sq_pessoa'), %(pes_tipo)s, %(pes_num_documento)s, %(pes_nome)s, %(pes_fantasia)s, %(pes_uf)s
         , %(pes_logradouro)s, %(pes_numero)s, %(pes_bairro)s, %(pes_descricao_cidade)s, %(pes_telefone1)s
         , %(pes_fax)s, %(pes_email)s
     WHERE NOT EXISTS (SELECT 1 FROM existente)
    RETURNING pes_codigo
)                                                       -- T-Agente-Pessoa-Agente_Financeiro
INSERT INTO pessoa_agente_financeiro (agf_codigo, pes_codigo, agf_codigo_banco)
SELECT %(agf_codigo)s, pes_codigo, %(agf_codigo_banco)s
  FROM (SELECT pes_codigo FROM existente UNION ALL SELECT pes_codigo FROM nova) AS p
