UPDATE tipo_recebimento
   SET tprdes = %(tprdes)s, tprtip = %(tprtip)s, tprdcn = %(tprdcn)s, tprnumaut = %(tprnumaut)s
     , tprprzrec = %(tprprzrec)s, tprprzjur = %(tprprzjur)s, tprprzmul = %(tprprzmul)s
     , tprperjur = %(tprperjur)s, tprpermul = %(tprpermul)s, tprtipjur = %(tprtipjur)s
     , tprimpdoc = %(tprimpdoc)s, tprnumvia = %(tprnumvia)s, tprvlrfix = %(tprvlrfix)s
 WHERE tprcod = %(tprcod)s
