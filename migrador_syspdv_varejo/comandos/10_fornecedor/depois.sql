-- Pentaho: "VF - Corrige Desoneracao ICMS" (fornecedores do RJ nao consideram desoneracao como desconto)
UPDATE pessoa_fornecedor
   SET for_considera_desoneracao_como_desconto = FALSE
 WHERE pes_codigo IN (SELECT pes_codigo FROM pessoa WHERE pes_uf = 'RJ');

-- Pentaho: "update holcod pessoa" - todas as pessoas recebem o holcod da loja matriz.
UPDATE pessoa
   SET holcod = (SELECT p.holcod
                   FROM pessoa p
                  INNER JOIN pessoa_loja pl ON (pl.pes_codigo = p.pes_codigo)
                  WHERE pl.loj_matriz = 'S'
                  LIMIT 1)
