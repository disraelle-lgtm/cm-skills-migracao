-- NCMs do cenario fiscal: so os NCMs que TEM classificacao tributaria (com CST) e que sao usados pelos produtos
-- migrados (o item NCM so leva esses para o VarejoFacil). Antes: classificacao em branco ('      ', nao nula) e NCM
-- sem produto migrado eram lidos e davam erro ("nao ha cenario..." / "ncm_codigo nao existe na tabela ncm").
-- DESEMPENHO: a lista de NCMs usados pelos produtos e montada UMA vez (subconsulta "usados", uma passada na PRODUTO)
-- e ligada aos NCMs. Um "NCMCOD IN (SELECT PRONCM FROM PRODUTO ...)" fazia o Firebird varrer a PRODUTO para cada NCM
-- (PRONCM costuma nao ter indice) e a etapa ficava muito lenta (versao 2026.11.33).
-- O filtro de produto segue as opcoes "fora de linha" e "So com movimentacao desde" (ancora do motor).
-- SQL comum a Firebird e SQL Server ('' ignora espacos a direita nos dois).
SELECT t1.NCMCOD, t1.CLATRBCODNFCE, t2.CSTCOD
  FROM (SELECT DISTINCT p.PRONCM
          FROM PRODUTO p
         WHERE p.PRONCM IS NOT NULL
           AND p.PRODES IS NOT NULL
           AND REPLACE(p.PROCOD, '0', '') <> ''
           AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)) usados
  JOIN NCM t1 ON t1.NCMCOD = usados.PRONCM
  JOIN CLASSIFICACAO_TRIBUTARIA t2 ON t2.CLATRBCOD = t1.CLATRBCODNFCE
 WHERE t1.CLATRBCODNFCE IS NOT NULL
   AND t1.CLATRBCODNFCE <> ''
   AND t2.CSTCOD IS NOT NULL
