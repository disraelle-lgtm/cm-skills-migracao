-- Um comando so grava pessoa + pessoa_cliente (as 2 transformacoes do Pentaho).
-- PESSOA FISICA / JURIDICA: Insert/Update pelo documento - se a pessoa ja existe (ex.: tambem
--   e fornecedor), ela e atualizada e reaproveitada. Clientes diferentes com o MESMO documento
--   ficam ligados a mesma pessoa (no Pentaho so o ultimo ficava, o primeiro se perdia).
-- PESSOA Sem CNPJ/CPF: sempre pessoa nova.
WITH existente AS (
    SELECT pes_codigo FROM pessoa
     WHERE %(pes_num_documento)s::text IS NOT NULL
       AND pes_num_documento = %(pes_num_documento)s::text
     ORDER BY pes_codigo LIMIT 1
), atualizada AS (
    UPDATE pessoa
       SET pes_tipo = %(pes_tipo)s
         , pes_num_documento = %(pes_num_documento)s
         , pes_num_identificacao = %(pes_num_identificacao)s
         , pes_insc_municipal = %(pes_insc_municipal)s
         , pes_nome = %(pes_nome)s
         , pes_cep = %(pes_cep)s
         , pes_uf = %(pes_uf)s
         , pes_pais = %(pes_pais)s
         , pes_logradouro = %(pes_logradouro)s
         , pes_numero = %(pes_numero)s
         , pes_complemento = %(pes_complemento)s
         , mcp_codigo_ibge = %(mcp_codigo_ibge)s
         , pes_descricao_cidade = %(pes_descricao_cidade)s
         , pes_telefone1 = %(pes_telefone1)s
         , pes_telefone2 = %(pes_telefone2)s
         , pes_fax = %(pes_fax)s
         , pes_email = %(pes_email)s
         , pes_fantasia = %(pes_fantasia)s
         , pes_rg_expedidor = %(pes_rg_expedidor)s
         , pes_bairro = %(pes_bairro)s
         , pes_data_cadastro = COALESCE(%(pes_data_cadastro)s::date, pes_data_cadastro)
     WHERE pes_codigo IN (SELECT pes_codigo FROM existente)
    RETURNING pes_codigo
), nova AS (
    INSERT INTO pessoa (pes_codigo, holcod, pes_data_cadastro, pes_tipo, pes_num_documento, pes_num_identificacao, pes_insc_municipal, pes_nome, pes_cep, pes_uf, pes_pais, pes_logradouro, pes_numero, pes_complemento, mcp_codigo_ibge, pes_descricao_cidade, pes_telefone1, pes_telefone2, pes_fax, pes_email, pes_fantasia, pes_rg_expedidor, pes_bairro)
    SELECT nextval('sq_pessoa'), 1, %(pes_data_cadastro)s::date, %(pes_tipo)s, %(pes_num_documento)s, %(pes_num_identificacao)s, %(pes_insc_municipal)s, %(pes_nome)s, %(pes_cep)s, %(pes_uf)s, %(pes_pais)s, %(pes_logradouro)s, %(pes_numero)s, %(pes_complemento)s, %(mcp_codigo_ibge)s, %(pes_descricao_cidade)s, %(pes_telefone1)s, %(pes_telefone2)s, %(pes_fax)s, %(pes_email)s, %(pes_fantasia)s, %(pes_rg_expedidor)s, %(pes_bairro)s
     WHERE NOT EXISTS (SELECT 1 FROM existente)
    RETURNING pes_codigo
)
INSERT INTO pessoa_cliente (cli_codigo, pes_codigo, cli_comp_data_nascimento, cli_comp_estado_civil, cli_comp_sexo, cli_comp_orgao_publico, cli_comp_retem_iss, cli_comp_atividade, cli_comp_naturalidade, cli_comp_observacao, cli_comp_tipo_residencia, cli_comp_tempo_residencia, cli_comp_temp_trab_emp_atual, cli_comp_comprovante_renda, cli_comp_situacao_aprovacao, cli_versao, stacod, ramcod, cli_comp_tipo_preco, cli_comp_pessoa_contato)
SELECT %(cli_codigo)s, pes_codigo, %(cli_comp_data_nascimento)s, %(cli_comp_estado_civil)s, %(cli_comp_sexo)s, %(cli_comp_orgao_publico)s, %(cli_comp_retem_iss)s, %(cli_comp_atividade)s, %(cli_comp_naturalidade)s, %(cli_comp_observacao)s, %(cli_comp_tipo_residencia)s, %(cli_comp_tempo_residencia)s, %(cli_comp_temp_trab_emp_atual)s, %(cli_comp_comprovante_renda)s, %(cli_comp_situacao_aprovacao)s, %(cli_versao)s, %(stacod)s, %(ramcod)s, %(cli_comp_tipo_preco)s, %(cli_comp_pessoa_contato)s
  FROM (SELECT pes_codigo FROM atualizada UNION ALL SELECT pes_codigo FROM nova) AS p
