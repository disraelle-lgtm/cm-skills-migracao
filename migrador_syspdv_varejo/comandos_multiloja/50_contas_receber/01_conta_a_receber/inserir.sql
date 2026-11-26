-- Loja adicional: identificador NOVO no VarejoFacil (o ctr_id do SysPDV recomeca em cada banco e colidia com o
-- da matriz), registrado no vinculo (conta_receber) para as etapas seguintes.
WITH novo AS (
INSERT INTO conta_a_receber (ctr_id, cli_codigo, loj_codigo, ctr_num_documento, ctr_observacao, ctr_data_emissao,
                             ctr_primeiro_vencimento, ctr_valor_nominal, ctr_valor_bruto, cfnc_codigo, agf_codigo,
                             ctr_dias_incidencia_juros, ctr_mora_diaria_atraso, ctr_dias_incidencia_multa,
                             ctr_valor_multa_por_atraso, ctr_condicao_pagamento, ctr_numero_titulos, ctr_modalidade,
                             ctr_origem_documento, edc_codigo)
VALUES ((SELECT COALESCE(MAX(ctr_id), 0) + 1 FROM conta_a_receber), (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text), {{loja_destino}}, %(ctr_num_documento)s, %(ctr_observacao)s, %(ctr_data_emissao)s,
        %(ctr_primeiro_vencimento)s, %(ctr_valor_nominal)s, %(ctr_valor_bruto)s, %(cfnc_codigo)s, 0,
        0, 0, 0,
        0, 'A_VISTA', 1, 'S',
        'AVULSO', (SELECT edc_codigo FROM especie_documento WHERE UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER' ORDER BY (UPPER(TRIM(edc_sigla)) = 'BR') DESC, (UPPER(TRIM(edc_genero)) = 'R') DESC, edc_codigo LIMIT 1))
    RETURNING ctr_id
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'conta_receber', %(ctr_id)s::text, ctr_id, TRUE FROM novo
