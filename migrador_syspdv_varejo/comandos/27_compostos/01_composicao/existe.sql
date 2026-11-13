-- Pentaho: chave comp_procod; quantidade e baixa com Update = Y
SELECT comp_quantidade, comp_baixa FROM composicao WHERE comp_procod = %(comp_procod)s
