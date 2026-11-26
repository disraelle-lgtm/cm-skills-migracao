-- So LIGA o funcionario que ja existe: vinculo + acesso a loja nova (nao principal). Nenhum dado da matriz e alterado.
WITH alvo AS (
    SELECT codigo_vf AS fun_codigo, 1 AS ordem FROM migracao_multiloja.vinculo
     WHERE loj_codigo = {{loja_destino}} AND tipo = 'funcionario' AND codigo_origem = %(funcod)s::text
    UNION ALL
    SELECT pf.fun_codigo, 2 FROM pessoa_funcionario pf JOIN pessoa p ON p.pes_codigo = pf.pes_codigo
     WHERE NULLIF(%(pes_num_documento)s::varchar, '') IS NOT NULL AND p.pes_num_documento = %(pes_num_documento)s::varchar
    UNION ALL
    -- SEM CPF: pelo NOME, so se houver UM UNICO funcionario com esse nome (caso real: funcionarios sem CPF nos dois
    -- bancos eram cadastrados de novo)
    SELECT pf.fun_codigo, 3 FROM pessoa_funcionario pf JOIN pessoa p ON p.pes_codigo = pf.pes_codigo
     WHERE NULLIF(%(pes_num_documento)s::varchar, '') IS NULL
       AND pf.fun_codigo < 1000000000
       AND UPPER(TRIM(p.pes_nome)) = UPPER(TRIM(%(pes_nome)s::varchar))
       AND (SELECT count(*) FROM pessoa_funcionario x JOIN pessoa y ON y.pes_codigo = x.pes_codigo
             WHERE x.fun_codigo < 1000000000 AND UPPER(TRIM(y.pes_nome)) = UPPER(TRIM(%(pes_nome)s::varchar))) = 1
    ORDER BY 2, 1 LIMIT 1
), vinc AS (
    INSERT INTO migracao_multiloja.vinculo (loj_codigo, tipo, codigo_origem, codigo_vf, novo)
    SELECT {{loja_destino}}, 'funcionario', %(funcod)s::text, fun_codigo, FALSE FROM alvo
    ON CONFLICT (loj_codigo, tipo, codigo_origem) DO NOTHING
    RETURNING 1
)
INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo, pfl_principal)
SELECT nextval('sq_funcionario_loja'), a.fun_codigo, {{loja_destino}}, %(pfl_ativo)s, FALSE
  FROM alvo a
 WHERE NOT EXISTS (SELECT 1 FROM pessoa_funcionario_loja x WHERE x.fun_codigo = a.fun_codigo AND x.loj_codigo = {{loja_destino}})
