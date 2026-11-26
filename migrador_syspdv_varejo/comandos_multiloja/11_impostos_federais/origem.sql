-- Pentaho: FB - IMPOSTOS_FEDERAIS
-- So os impostos com situacao tributaria de entrada diferente da de saida (regra do Pentaho) - e TAMBEM os que
-- tem a situacao de entrada ou de saida VAZIA (nula): vao com o campo vazio para corrigir na aplicacao. Antes o
-- nulo ficava de fora (NULL <> X nao e verdadeiro) e uma base com IMPFEDST nulo migrava so os impostos completos.
SELECT IMPFEDSIM, IMPFEDDES, IMPFEDINC, IMPFEDALQ, IMPFEDALQSAI, IMPFEDRET
     , IPMFEDOBS, IMPFEDTIP, IMPFEDST, IMPFEDSTSAI, IMPFEDNATBAS
  FROM IMPOSTOS_FEDERAIS
 WHERE (IMPFEDST IS NULL OR IMPFEDSTSAI IS NULL OR IMPFEDST <> IMPFEDSTSAI)
 ORDER BY 1
