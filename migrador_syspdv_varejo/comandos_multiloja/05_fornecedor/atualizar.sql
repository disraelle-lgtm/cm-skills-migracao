-- So grava o vinculo (codigo desta loja no SysPDV -> fornecedor que ja existia). Nada e alterado na matriz.
WITH alvo AS (
    SELECT codigo_vf AS codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'fornecedor' AND codigo_origem = %(for_codigo)s::text
    UNION ALL
    SELECT x.for_codigo, 2 FROM pessoa_fornecedor x JOIN pessoa p ON p.pes_codigo = x.pes_codigo
     WHERE p.pes_num_documento = %(pes_num_documento)s::varchar
    ORDER BY 2, 1 LIMIT 1
)
INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
SELECT {{loja_destino}}, 'fornecedor', %(for_codigo)s::text, codigo, FALSE FROM alvo
ON CONFLICT (loj_codigo, tipo, codigo_origem) DO NOTHING
