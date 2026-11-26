-- Loja adicional: identificador NOVO no VarejoFacil (o ctp_id do SysPDV recomeca em cada banco e colidia com o
-- da matriz), registrado no vinculo (conta_pagar) para as etapas seguintes.
WITH novo AS (
INSERT INTO conta_a_pagar (ctp_id, ctp_data_emissao, ctp_primeiro_vencimento, ctp_observacao, ctp_valor_nominal,
                           ctp_valor_bruto, loj_codigo, for_codigo, agf_codigo, cfnc_codigo, ctp_modalidade,
                           ctp_dias_incidencia_juros, ctp_mora_diaria_atraso, ctp_dias_incidencia_multa,
                           ctp_valor_multa_por_atraso, ctp_numero_titulos, ctp_origem_documento, ctp_num_documento, edc_codigo)
VALUES ((SELECT COALESCE(MAX(ctp_id), 0) + 1 FROM conta_a_pagar), %(ctp_data_emissao)s, %(ctp_primeiro_vencimento)s, %(ctp_observacao)s, %(ctp_valor_nominal)s,
        %(ctp_valor_bruto)s, {{loja_destino}}, (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'fornecedor' AND codigo_origem = %(for_codigo)s::text), 0, %(cfnc_codigo)s, 'S',
        0, 0, 0,
        0, 1, 'AVULSO', %(ctp_num_documento)s, (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO PAGAR' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BP') DESC, (UPPER(TRIM(edc_genero)) = 'P') DESC, edc_codigo LIMIT 1))
    RETURNING ctp_id
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'conta_pagar', %(ctp_id)s::text, ctp_id, TRUE FROM novo
