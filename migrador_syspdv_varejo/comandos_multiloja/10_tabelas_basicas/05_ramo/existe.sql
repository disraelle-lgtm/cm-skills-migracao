-- No Pentaho o Ramo esta com "nao atualizar" (update_bypassed): so insere o que falta.
-- Por isso nao existe atualizar.sql nesta pasta.
SELECT ramcod FROM ramo WHERE ramcod = %(ramcod)s
