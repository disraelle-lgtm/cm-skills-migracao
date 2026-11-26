-- o pai (o grupo) precisa ter sido migrado
SELECT 1 WHERE (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'grupo' AND codigo_origem = %(seccod)s::int::text || '|' || %(grpcod)s::int::text) IS NOT NULL
