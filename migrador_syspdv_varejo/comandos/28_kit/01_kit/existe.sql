-- Pentaho: chave comp_procod. O Pentaho tambem trocava o comp_id (Update = Y) por um numero novo a
-- cada execucao, deixando os componentes ja gravados sem composicao; aqui o comp_id e mantido.
SELECT comp_quantidade, comp_baixa, comp_tipo FROM composicao WHERE comp_procod = %(comp_procod)s
