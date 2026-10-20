SELECT v.clicod AS "Código Cliente"
     , v.agedes AS "Nome/Razão Social"
     , v.agefan AS "Nome Fantasia"
     , v.agecgccpf AS "CPF/CNPJ"
     , v.agecgfrg AS "RG/Inscricao Estadual"
     , COALESCE(v.ageorgexp,'') AS "Órgão Emissor RG"
     , v.agepfpj AS "Tipo"
     , v.agedatcad AS "Data de Cadastro do Cliente"
     , v.ageend AS "Endereço"
     , v.agebai AS "Bairro"
     , v.agenum AS "Número"
     , v.agecpl AS "Complemento"
     , v.agecep AS "CEP"
     , COALESCE(v.agecorele,'cliente@cliente.com.br') AS agecorele
     , COALESCE(v.agetel1,'') AS "Telefone"
     , COALESCE(v.agetel2,'') AS "Celular"
     , COALESCE(v.agefax,'') AS agefax
     , v.agecid AS "Cidade"
     , v.ageest AS "UF"
     , c.cidcodibge AS "Classe Fiscal"
     , COALESCE(v.pascod,'001058') AS "País"
     , COALESCE(v.lojcod,'') AS "loja"
     , COALESCE(v.clidatnas,'') AS "Data de Nascimento"
     , COALESCE(v.clilimcre,'0') AS "Limite de crédito"
     , COALESCE(v.cliestciv,'') AS "Estado civil"
     , COALESCE(v.clisex,'') AS "Sexo"
     , CONCAT(v.stacod, ' - ', s.stades) AS status
  FROM dbo.v_cliente v
  JOIN dbo.cidade c ON v.agecodcid = c.cidcod
  JOIN dbo.status s ON v.stacod = s.stacod
 WHERE v.clicod != '000000000000000'
   AND v.agedes IS NOT NULL
 ORDER BY v.clicod ;