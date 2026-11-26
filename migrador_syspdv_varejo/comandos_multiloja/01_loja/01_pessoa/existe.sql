-- Pessoa da loja (CNPJ) ja existe no VarejoFacil: e MANTIDA como esta (nenhuma coluna comparada = sem alteracao).
SELECT pes_codigo FROM pessoa WHERE pes_num_documento = %(pes_num_documento)s ORDER BY pes_codigo LIMIT 1
