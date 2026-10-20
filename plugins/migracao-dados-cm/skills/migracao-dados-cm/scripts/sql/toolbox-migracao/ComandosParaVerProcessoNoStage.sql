COMANDO PARA VERO PROCESSO NO stage
SELECT pid,datname,state, wait_event, wait_event_type, xact_start AT TIME ZONE 'ADT', NOW() - xact_start, NOW() - query_start, NOW() - state_change AS "Tempo de Execucao", query FROM pg_stat_activity  WHERE datname = 'naturecosmeticos' and state != 'idle'  ORDER BY 8 DESC ;

COMANDO PARA MATAR O PROCESSO NO BANCO
select pg_terminate_backend(9930) ; --pid do processo