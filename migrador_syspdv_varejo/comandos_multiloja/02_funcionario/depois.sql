-- Pentaho: "Atualiza a Sequence" (o insert usa sq_funcionario_loja; o ajuste e na
-- sq_pessoa_funcionario_loja - os dois nomes estao assim no job original).
SELECT SETVAL('sq_pessoa_funcionario_loja', COALESCE((SELECT MAX(pfl_id) FROM pessoa_funcionario_loja), 0) + 1, FALSE);
-- Pentaho: "update holcod pessoa" - todas as pessoas recebem o holcod da loja matriz.
UPDATE pessoa
   SET holcod = (SELECT p.holcod
                   FROM pessoa p
                  INNER JOIN pessoa_loja pl ON (pl.pes_codigo = p.pes_codigo)
                  WHERE pl.loj_matriz = 'S'
                  LIMIT 1);

-- Pentaho: "Insert Usuario" - cria usuario (senha padrao 'admin') para quem ainda nao tem.
INSERT INTO usuario (funcod, usunom, ususen, administrador, ativo, ultima_alteracao_senha)
SELECT pf.fun_codigo, p.pes_nome, md5('admin'), FALSE, TRUE, NOW()
  FROM pessoa_funcionario pf
  JOIN pessoa p ON (pf.pes_codigo = p.pes_codigo)
 WHERE pf.fun_codigo NOT IN (SELECT u.funcod FROM usuario u WHERE u.funcod IS NOT NULL)
