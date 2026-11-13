import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
import pytest
from seguranca import SqlNaoPermitido, validar_somente_leitura as v, validar_identificador as vi

OK = [
    "SELECT * FROM PRODUTO",
    "select first 10 * from produto;",
    "  WITH t AS (SELECT 1 AS a FROM RDB$DATABASE) SELECT * FROM t",
    "SELECT TOP (5) * FROM dbo.Produto",
    "SELECT * FROM PRODUTO WHERE DESCRICAO = 'UPDATE DELETE DROP'",          # palavra dentro de texto
    "SELECT DATA_UPDATE, ULTIMO_DELETE FROM LOG",                              # palavra dentro de nome
    'SELECT "UPDATE" FROM T',                                                  # identificador entre aspas
    "SELECT [Update] FROM T",
    "SELECT * FROM T WHERE X = 'It''s; ok'",                                   # ; dentro de texto
    "SELECT 1 -- DROP TABLE X",                                                # palavra em comentário
    "SELECT /* DELETE FROM X */ 1",
    "SELECT GEN_ID(GEN_PRODUTO, 0) FROM RDB$DATABASE",
    "(SELECT 1 FROM RDB$DATABASE)",
]
NEGADOS = [
    "", "   ",
    "DELETE FROM PRODUTO",
    "UPDATE PRODUTO SET X = 1",
    "INSERT INTO PRODUTO VALUES (1)",
    "DROP TABLE PRODUTO",
    "SELECT * FROM A; DROP TABLE A",
    "SELECT 1; SELECT 2",
    "SELECT * INTO NOVA FROM PRODUTO",
    "EXEC sp_who",
    "EXECUTE BLOCK AS BEGIN END",
    "SELECT * FROM T FOR UPDATE WITH LOCK",
    "WITH x AS (SELECT 1) DELETE FROM T",
    "SELECT GEN_ID(GEN_PRODUTO, 1) FROM RDB$DATABASE",
    "SELECT GEN_ID(GEN_PRODUTO, -1) FROM RDB$DATABASE",
    "SELECT NEXT VALUE FOR seq FROM X",
    "SELECT * FROM OPENROWSET('x','y','z')",
    "SELECT xp_cmdshell 'dir'",
    "SELECT 1 /* comentário aberto",
    "SELECT 'texto aberto",
    "SET GENERATOR G TO 0",
    "SELECT 1 /**/ ; /**/ DROP TABLE X",
    "SELECT 1;--\nDROP TABLE X",
    "SELECT 1 FROM T WHERE X = 1 OR 1=1; TRUNCATE TABLE T",
    "SELECT 1 FROM A COMMIT",
]


@pytest.mark.parametrize("sql", OK)
def test_aceita(sql):
    assert v(sql)


@pytest.mark.parametrize("sql", NEGADOS)
def test_recusa(sql):
    with pytest.raises(SqlNaoPermitido):
        v(sql)


def test_devolve_sql_original_sem_ponto_e_virgula():
    assert v("SELECT 'a;b' FROM X ;;") == "SELECT 'a;b' FROM X"


@pytest.mark.parametrize("n", ["PRODUTO", "dbo.Produto", "TB_X$1"])
def test_identificador_ok(n):
    assert vi(n) == n


@pytest.mark.parametrize("n", ["", "A;B", "A B", "A-B", "a.b.c", "x'--", '"X"', "[x]", "1abc"])
def test_identificador_invalido(n):
    with pytest.raises(SqlNaoPermitido):
        vi(n)
