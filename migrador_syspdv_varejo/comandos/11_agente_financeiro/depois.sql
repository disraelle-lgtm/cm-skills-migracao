-- Pentaho: "VF - update_holcod_pessoa" - todas as pessoas recebem o holcod da loja matriz.
UPDATE pessoa
   SET holcod = (SELECT p.holcod
                   FROM pessoa p
                  INNER JOIN pessoa_loja pl ON (pl.pes_codigo = p.pes_codigo)
                  WHERE pl.loj_matriz = 'S'
                  LIMIT 1)
