import json, sqlite3, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
import pytest
import conexoes, server


@pytest.fixture()
def amb(tmp_path, monkeypatch):
    cfg = {
        "limite_linhas_padrao": 5, "limite_linhas_maximo": 8,
        "conexoes": {
            "fb": {"tipo": "firebird", "banco": "x.fdb", "senha_env": "X", "descricao": "FB teste"},
            "ms": {"tipo": "sqlserver", "banco": "ERP", "senha_env": "X"},
        },
    }
    arq = tmp_path / "c.json"; arq.write_text(json.dumps(cfg), encoding="utf-8")
    monkeypatch.setenv("MCP_BANCOS_CONFIG", str(arq))
    monkeypatch.setattr(server, "AUDITORIA", tmp_path / "aud.log")

    def fake(nome, c, timeout):
        con = sqlite3.connect(":memory:")
        con.execute("CREATE TABLE P (ID INTEGER, NOME TEXT, SENHA TEXT, PRECO NUMERIC, FOTO BLOB)")
        con.executemany("INSERT INTO P VALUES (?,?,?,?,?)", [(i, f"item{i}", "segredo", i * 1.5, b"\x00\x01") for i in range(1, 21)])
        con.commit()
        return con
    monkeypatch.setattr(conexoes, "conectar", fake)
    return tmp_path


def test_listar_conexoes_sem_senha(amb):
    r = server.listar_conexoes()
    assert {x["nome"] for x in r} == {"fb", "ms"}
    assert "senha" not in json.dumps(r).lower().replace("senha_env", "")


def test_consulta_limite_padrao_e_truncado(amb):
    r = server.executar_consulta("fb", "SELECT ID FROM P ORDER BY ID")
    assert r["linhas_retornadas"] == 5 and r["truncado"] is True and r["limite"] == 5


def test_limite_nao_passa_do_maximo(amb):
    r = server.executar_consulta("fb", "SELECT ID FROM P", limite=999)
    assert r["limite"] == 8 and r["linhas_retornadas"] == 8 and r["truncado"]


def test_sem_truncar_quando_cabe(amb):
    r = server.executar_consulta("fb", "SELECT ID FROM P WHERE ID <= 3")
    assert r["linhas_retornadas"] == 3 and r["truncado"] is False


def test_mascara_e_binario(amb):
    r = server.executar_consulta("fb", "SELECT NOME, SENHA, FOTO FROM P WHERE ID = 1")
    assert r["linhas"][0] == ["item1", "***", "<binário 2 bytes>"]


def test_bloqueia_escrita_e_audita(amb):
    with pytest.raises(ValueError, match="recusado"):
        server.executar_consulta("fb", "DELETE FROM P")
    assert "BLOQUEADO" in (amb / "aud.log").read_text(encoding="utf-8")


def test_conexao_inexistente(amb):
    with pytest.raises(ValueError, match="não existe"):
        server.executar_consulta("nada", "SELECT 1")


def test_erro_do_banco_vira_mensagem(amb):
    with pytest.raises(ValueError, match="Erro ao executar"):
        server.executar_consulta("fb", "SELECT * FROM NAO_EXISTE")


def test_conexao_fechada_ao_final(amb, monkeypatch):
    abertas = []
    real = conexoes.conectar
    monkeypatch.setattr(conexoes, "conectar", lambda n, c, t: abertas.append(real(n, c, t)) or abertas[-1])
    server.executar_consulta("fb", "SELECT 1 AS A")
    with pytest.raises(Exception):
        abertas[0].execute("SELECT 1")  # já fechada


def test_amostra_gera_sql_por_tipo(amb, monkeypatch):
    vistos = []
    monkeypatch.setattr(server, "_rodar", lambda cfg, n, sql, params=(), limite=None, teto=None: vistos.append(sql) or {})
    server.amostra_tabela("fb", "produto", 7)
    server.amostra_tabela("ms", "dbo.Produto", 500)
    assert vistos == ['SELECT FIRST 7 * FROM "PRODUTO"', "SELECT TOP (100) * FROM [dbo].[Produto]"]


def test_amostra_recusa_nome_malicioso(amb):
    with pytest.raises(ValueError, match="inválido"):
        server.amostra_tabela("fb", 'P"; DROP TABLE P; --')


def test_formatadores_de_tipo():
    assert server._tipo_firebird({"TIPO": "VARYING", "TAMANHO": 60, "ESCALA": 0, "PRECISAO": 0, "SUBTIPO": 0}) == "VARCHAR(60)"
    assert server._tipo_firebird({"TIPO": "INT64", "TAMANHO": None, "ESCALA": -2, "PRECISAO": 18, "SUBTIPO": 1}) == "NUMERIC(18,2)"
    assert server._tipo_firebird({"TIPO": "LONG", "TAMANHO": None, "ESCALA": 0, "PRECISAO": 0, "SUBTIPO": 0}) == "INTEGER"
    assert server._tipo_sqlserver({"TIPO": "varchar", "TAMANHO": -1, "PRECISAO": None, "ESCALA": None}) == "varchar(max)"
    assert server._tipo_sqlserver({"TIPO": "decimal", "TAMANHO": None, "PRECISAO": 18, "ESCALA": 4}) == "decimal(18,4)"


def test_config_recusa_senha_no_arquivo(tmp_path):
    a = tmp_path / "c.json"
    a.write_text(json.dumps({"conexoes": {"x": {"tipo": "firebird", "banco": "b", "senha": "123"}}}), encoding="utf-8")
    with pytest.raises(conexoes.ErroConfig, match="senha_env"):
        conexoes.carregar_config(a)


def test_string_de_conexao_odbc_escapa():
    assert conexoes._escapar_odbc("a}b;c") == "{a}}b;c}"
