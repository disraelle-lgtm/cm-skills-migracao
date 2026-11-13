INSERT INTO grupo_produto (grpid, seccod, grpcod, grpdes)
VALUES (nextval('sq_grupo_produto'), %(seccod)s, %(grpcod)s, %(grpdes)s)
