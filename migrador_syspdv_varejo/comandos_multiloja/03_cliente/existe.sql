-- Cliente ja no VarejoFacil (vinculo desta loja ou mesmo CPF/CNPJ): so o indicador do vinculo - os dados da matriz
-- NAO sao comparados nem alterados (regra do usuario: manter a matriz).
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'cliente' AND codigo_origem = %(cli_codigo)s::text
    UNION ALL
    SELECT x.cli_codigo, 2 FROM pessoa_cliente x JOIN pessoa p ON p.pes_codigo = x.pes_codigo
     WHERE p.pes_num_documento = %(pes_num_documento)s::varchar
    ORDER BY 2, 1 LIMIT 1
)
SELECT EXISTS (SELECT 1 FROM migracao_multiloja.vinculo v WHERE v.loj_codigo = {{loja_destino}} AND v.tipo = 'cliente' AND v.codigo_origem = %(cli_codigo)s::text) AS vinculado_loja
  FROM alvo
