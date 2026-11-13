-- Pentaho: todos os campos com Update = Y
UPDATE conta_corrente
   SET cct_descricao = %(cct_descricao)s
     , cct_tipo = %(cct_tipo)s
     , loj_codigo = %(loj_codigo)s
     , agf_codigo = %(agf_codigo)s
     , cct_agencia = %(cct_agencia)s
     , cct_conta = %(cct_conta)s
     , cct_local_pagamento = %(cct_local_pagamento)s
 WHERE cct_codigo = %(cct_codigo)s
