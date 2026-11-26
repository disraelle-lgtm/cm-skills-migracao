-- Funcionario ja no VarejoFacil (pelo vinculo desta loja ou pelo CPF): so indicadores - os dados da matriz NAO sao
-- comparados nem alterados. Falta o vinculo ou o acesso a loja nova -> atualizar.sql (so liga).
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
)
SELECT EXISTS (SELECT 1 FROM migracao_multiloja.vinculo v WHERE v.loj_codigo = {{loja_destino}} AND v.tipo = 'funcionario' AND v.codigo_origem = %(funcod)s::text) AS vinculado_loja
     , EXISTS (SELECT 1 FROM pessoa_funcionario_loja x WHERE x.fun_codigo = a.fun_codigo AND x.loj_codigo = {{loja_destino}}) AS acesso_loja
  FROM alvo a
