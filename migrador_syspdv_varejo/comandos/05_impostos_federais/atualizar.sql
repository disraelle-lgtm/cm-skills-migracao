-- Diferenca proposital em relacao ao Pentaho: os 4 IDs (geral/atacado/simples/varejo) NAO
-- sao trocados no UPDATE. O Pentaho gerava IDs novos a cada execucao, o que deixava as
-- tabelas _geral/_atacado/_simples/_varejo apontando para IDs antigos numa segunda rodada.
UPDATE impostos_federais
   SET impfeddes = %(impfeddes)s, impfedinc = %(impfedinc)s, impfedalq = %(impfedalq)s
     , impfedalqsai = %(impfedalqsai)s, impfedret = %(impfedret)s, ipmfedobs = %(ipmfedobs)s
     , impfedtip = %(impfedtip)s, impfedst = %(impfedst)s, impfedstsai = %(impfedstsai)s
     , impfednatbas = %(impfednatbas)s
 WHERE impfedsim = %(impfedsim)s
