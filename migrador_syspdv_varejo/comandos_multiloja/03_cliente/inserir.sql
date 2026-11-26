-- Cliente NOVO na loja adicional: pessoa de mesmo CPF/CNPJ (ex.: fornecedor da matriz) e reaproveitada SEM alterar;
-- senao pessoa nova. Codigo = proximo livre (< 999999), loja = a nova, vinculo novo = TRUE.
WITH existente AS (
    SELECT pes_codigo FROM pessoa
     WHERE %(pes_num_documento)s::varchar IS NOT NULL
       AND pes_num_documento = %(pes_num_documento)s::varchar
     ORDER BY pes_codigo LIMIT 1
), nova AS (
    INSERT INTO pessoa (pes_codigo, holcod, pes_data_cadastro, pes_tipo, pes_num_documento, pes_num_identificacao, pes_insc_municipal, pes_nome, pes_cep, pes_uf, pes_pais, pes_logradouro, pes_numero, pes_complemento, mcp_codigo_ibge, pes_descricao_cidade, pes_telefone1, pes_telefone2, pes_fax, pes_email, pes_fantasia, pes_rg_expedidor, pes_bairro)
    SELECT nextval('sq_pessoa'), 1, %(pes_data_cadastro)s::date, %(pes_tipo)s, %(pes_num_documento)s::varchar, %(pes_num_identificacao)s, %(pes_insc_municipal)s, %(pes_nome)s, %(pes_cep)s, %(pes_uf)s, %(pes_pais)s, %(pes_logradouro)s, %(pes_numero)s, %(pes_complemento)s, %(mcp_codigo_ibge)s, %(pes_descricao_cidade)s, %(pes_telefone1)s, %(pes_telefone2)s, %(pes_fax)s, %(pes_email)s, %(pes_fantasia)s, %(pes_rg_expedidor)s, %(pes_bairro)s
     WHERE NOT EXISTS (SELECT 1 FROM existente)
    RETURNING pes_codigo
), novo_cliente AS (
    INSERT INTO pessoa_cliente (cli_codigo, loj_codigo, pes_codigo, cli_comp_data_nascimento, cli_comp_estado_civil, cli_comp_sexo, cli_comp_orgao_publico, cli_comp_retem_iss, cli_comp_atividade, cli_comp_naturalidade, cli_comp_observacao, cli_comp_tipo_residencia, cli_comp_tempo_residencia, cli_comp_temp_trab_emp_atual, cli_comp_comprovante_renda, cli_comp_situacao_aprovacao, cli_versao, stacod, ramcod, cli_comp_tipo_preco, cli_comp_pessoa_contato)
SELECT (SELECT COALESCE(MAX(cli_codigo), 0) + 1 FROM pessoa_cliente WHERE cli_codigo < 999999), {{loja_destino}}, pes_codigo, %(cli_comp_data_nascimento)s, %(cli_comp_estado_civil)s, %(cli_comp_sexo)s, %(cli_comp_orgao_publico)s, %(cli_comp_retem_iss)s, %(cli_comp_atividade)s, %(cli_comp_naturalidade)s, %(cli_comp_observacao)s, %(cli_comp_tipo_residencia)s, %(cli_comp_tempo_residencia)s, %(cli_comp_temp_trab_emp_atual)s, %(cli_comp_comprovante_renda)s, %(cli_comp_situacao_aprovacao)s, %(cli_versao)s, %(stacod)s, %(ramcod)s, %(cli_comp_tipo_preco)s, %(cli_comp_pessoa_contato)s
  FROM (SELECT pes_codigo FROM existente UNION ALL SELECT pes_codigo FROM nova) AS p
    RETURNING cli_codigo
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'cliente', %(cli_codigo)s::text, cli_codigo, TRUE FROM novo_cliente
