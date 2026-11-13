-- ID pela sequence sq_pessoa; tipo JURIDICA e data de cadastro = hoje (so na inclusao, como no Pentaho)
INSERT INTO pessoa (pes_codigo, pes_num_documento, pes_tipo, pes_data_cadastro, pes_num_identificacao, pes_nome, pes_fantasia, pes_cep, pes_uf, pes_logradouro, pes_numero, pes_bairro, pes_complemento, pes_descricao_cidade, pes_telefone1, pes_fax, pes_email, pes_insc_municipal, mcp_codigo_ibge, pes_pais)
VALUES (nextval('sq_pessoa'), %(pes_num_documento)s, 'JURIDICA', now(),
        %(pes_num_identificacao)s, %(pes_nome)s, %(pes_fantasia)s, %(pes_cep)s, %(pes_uf)s, %(pes_logradouro)s, %(pes_numero)s, %(pes_bairro)s, %(pes_complemento)s, %(pes_descricao_cidade)s, %(pes_telefone1)s, %(pes_fax)s, %(pes_email)s, %(pes_insc_municipal)s, %(mcp_codigo_ibge)s, %(pes_pais)s)
