SELECT grpid, grpdes
  FROM grupo_produto
 WHERE seccod = %(seccod)s
   AND grpcod = %(grpcod)s
