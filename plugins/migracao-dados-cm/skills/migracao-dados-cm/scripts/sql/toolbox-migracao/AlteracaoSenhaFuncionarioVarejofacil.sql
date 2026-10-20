-- Alterando a senha do funcionário do VF


update usuario set ususen = md5('admin') where funcod = 1;

#-------#-------#-------#-------#-------  OU   -------#-------#-------#-------#-------#

UPDATE usuario 
  SET ativo = true, 
      administrador = true, 
      reset_senha = false, 
      ususen = (SELECT md5('admin')) 
WHERE funcod = 1 ;