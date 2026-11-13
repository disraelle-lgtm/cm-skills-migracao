-- Atencao: a sequence do subgrupo se chama sq_sub_grupo_produto (com "sub_grupo").
INSERT INTO subgrupo_produto (sgpid, seccod, grpcod, sgpcod, sgpdes)
VALUES (nextval('sq_sub_grupo_produto'), %(seccod)s, %(grpcod)s, %(sgpcod)s, %(sgpdes)s)
