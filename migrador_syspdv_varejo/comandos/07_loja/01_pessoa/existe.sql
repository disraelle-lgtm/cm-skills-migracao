-- Pentaho: Insert/Update pela chave PRPCGC = pes_num_documento
SELECT pes_codigo, pes_num_identificacao, pes_nome, pes_fantasia, pes_cep, pes_uf, pes_logradouro, pes_numero, pes_bairro, pes_complemento, pes_descricao_cidade, pes_telefone1, pes_fax, pes_email, pes_insc_municipal, mcp_codigo_ibge, pes_pais
  FROM pessoa
 WHERE pes_num_documento = %(pes_num_documento)s
 ORDER BY pes_codigo
 LIMIT 1
