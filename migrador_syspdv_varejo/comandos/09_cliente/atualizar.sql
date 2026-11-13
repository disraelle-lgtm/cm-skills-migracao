-- Campos com Update = Y no Pentaho (pessoa e pessoa_cliente).
WITH pessoa_do_cliente AS (
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
     WHERE pes_codigo = (SELECT pes_codigo FROM pessoa_cliente WHERE cli_codigo = %(cli_codigo)s LIMIT 1)
    RETURNING pes_codigo
)
UPDATE pessoa_cliente
   SET cli_comp_data_nascimento = %(cli_comp_data_nascimento)s
         , cli_comp_estado_civil = %(cli_comp_estado_civil)s
         , cli_comp_sexo = %(cli_comp_sexo)s
         , cli_comp_orgao_publico = %(cli_comp_orgao_publico)s
         , cli_comp_retem_iss = %(cli_comp_retem_iss)s
         , cli_comp_atividade = %(cli_comp_atividade)s
         , cli_comp_naturalidade = %(cli_comp_naturalidade)s
         , cli_comp_observacao = %(cli_comp_observacao)s
         , cli_comp_tipo_residencia = %(cli_comp_tipo_residencia)s
         , cli_comp_tempo_residencia = %(cli_comp_tempo_residencia)s
         , cli_comp_temp_trab_emp_atual = %(cli_comp_temp_trab_emp_atual)s
         , cli_comp_comprovante_renda = %(cli_comp_comprovante_renda)s
         , cli_comp_situacao_aprovacao = %(cli_comp_situacao_aprovacao)s
         , cli_versao = %(cli_versao)s
         , stacod = %(stacod)s
         , ramcod = %(ramcod)s
         , cli_comp_tipo_preco = %(cli_comp_tipo_preco)s
         , cli_comp_pessoa_contato = %(cli_comp_pessoa_contato)s
 WHERE cli_codigo = %(cli_codigo)s
