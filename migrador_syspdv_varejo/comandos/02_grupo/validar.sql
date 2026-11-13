-- Precisa devolver uma linha; senao o grupo vira erro "orfao" no relatorio.
SELECT 1 FROM secao WHERE seccod = %(seccod)s
