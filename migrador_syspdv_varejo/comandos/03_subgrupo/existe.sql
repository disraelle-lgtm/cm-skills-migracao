SELECT sgpid, sgpdes
  FROM subgrupo_produto
 WHERE seccod = %(seccod)s
   AND grpcod = %(grpcod)s
   AND sgpcod = %(sgpcod)s
