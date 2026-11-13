-- O cliente e localizado pela pessoa_cliente (permanente). O Pentaho usava a coluna
-- temporaria cli_codigo_syspdv (apagada no fim) e duplicava pessoas numa segunda execucao.
-- pes_data_cadastro so e comparada quando o SysPDV tem a data (senao vale a do VarejoFacil).
SELECT p.pes_tipo, p.pes_num_documento, p.pes_num_identificacao, p.pes_insc_municipal, p.pes_nome, p.pes_cep, p.pes_uf, p.pes_pais, p.pes_logradouro, p.pes_numero, p.pes_complemento, p.mcp_codigo_ibge, p.pes_descricao_cidade, p.pes_telefone1, p.pes_telefone2, p.pes_fax, p.pes_email, p.pes_fantasia, p.pes_rg_expedidor, p.pes_bairro
     , CASE WHEN %(pes_data_cadastro)s::date IS NULL THEN NULL ELSE p.pes_data_cadastro END AS pes_data_cadastro
     , pc.cli_comp_data_nascimento, pc.cli_comp_estado_civil, pc.cli_comp_sexo, pc.cli_comp_orgao_publico, pc.cli_comp_retem_iss, pc.cli_comp_atividade, pc.cli_comp_naturalidade, pc.cli_comp_observacao, pc.cli_comp_tipo_residencia, pc.cli_comp_tempo_residencia, pc.cli_comp_temp_trab_emp_atual, pc.cli_comp_comprovante_renda, pc.cli_comp_situacao_aprovacao, pc.cli_versao, pc.stacod, pc.ramcod, pc.cli_comp_tipo_preco, pc.cli_comp_pessoa_contato
  FROM pessoa_cliente pc
  JOIN pessoa p ON (p.pes_codigo = pc.pes_codigo)
 WHERE pc.cli_codigo = %(cli_codigo)s
 LIMIT 1
