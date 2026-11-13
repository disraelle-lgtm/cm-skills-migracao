SELECT tprdes, tprtip, tprdcn, tprnumaut, tprprzrec, tprprzjur, tprprzmul, tprperjur
     , tprpermul, tprtipjur, tprimpdoc, tprnumvia, tprvlrfix
  FROM tipo_recebimento
 WHERE tprcod = %(tprcod)s
