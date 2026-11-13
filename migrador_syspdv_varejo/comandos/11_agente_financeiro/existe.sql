-- O agente e localizado pela pessoa_agente_financeiro (permanente). O Pentaho usava a coluna
-- temporaria age_codigo_syspdv, apagada no fim, e criava a pessoa de novo numa segunda execucao.
SELECT agf_codigo_banco FROM pessoa_agente_financeiro WHERE agf_codigo = %(agf_codigo)s LIMIT 1
