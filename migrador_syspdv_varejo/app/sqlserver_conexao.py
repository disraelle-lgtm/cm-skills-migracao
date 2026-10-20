"""
Conexao com o SysPDV em SQL Server (origem), via ODBC (pyodbc). So leitura.

O pyodbc so e carregado quando a origem escolhida e SQL Server: quem usa so Firebird nao
precisa de nada disso instalado.

Driver ODBC: usa o informado na tela ou escolhe sozinho, nesta ordem:
  ODBC Driver 18 for SQL Server, ODBC Driver 17 for SQL Server, SQL Server Native Client 11.0,
  SQL Server (este ultimo ja vem com o Windows).
Linux: precisa do unixodbc (o instalar.sh instala) e do msodbcsql18 da Microsoft (ver LEIA-ME).
"""
from __future__ import annotations

import sys
from dataclasses import dataclass

PREFERIDOS = ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server",
              "SQL Server Native Client 11.0", "SQL Server"]


@dataclass
class ConexaoSqlServer:
    host: str = "localhost"
    porta: int = 1433
    instancia: str | None = None      # ex.: SQLEXPRESS (deixe vazio se usa porta)
    banco: str = ""
    usuario: str = "sa"
    senha: str = ""
    driver: str | None = None          # vazio = escolher sozinho
    string_odbc: str | None = None     # avancado: string de conexao ODBC completa (ignora o resto)


def _pyodbc():
    try:
        import pyodbc  # noqa: WPS433 (import tardio de proposito)
        return pyodbc
    except ImportError as e:
        texto = str(e)
        if "libodbc" in texto:
            raise RuntimeError("Falta o unixODBC no Linux: sudo apt install unixodbc") from e
        raise RuntimeError("Falta o pacote pyodbc: rode de novo o instalador do migrador") from e


def drivers_disponiveis() -> list[str]:
    return list(_pyodbc().drivers())


def escolher_driver(informado: str | None) -> str:
    instalados = drivers_disponiveis()
    if informado:
        if informado not in instalados:
            raise RuntimeError(f"Driver ODBC '{informado}' nao esta instalado. Instalados: {', '.join(instalados) or 'nenhum'}")
        return informado
    for d in PREFERIDOS:
        if d in instalados:
            return d
    raise RuntimeError(
        "Nenhum driver ODBC do SQL Server instalado. "
        + ("Instale o 'ODBC Driver 18 for SQL Server' da Microsoft." if sys.platform.startswith("win")
           else "No Linux instale o msodbcsql18 (passo a passo no linux/LEIA-ME.md).")
        + f" Drivers encontrados: {', '.join(instalados) or 'nenhum'}")


def string_conexao(c: ConexaoSqlServer) -> str:
    if c.string_odbc:
        return c.string_odbc
    driver = escolher_driver(c.driver)
    servidor = f"{c.host}\\{c.instancia}" if c.instancia else f"{c.host},{c.porta or 1433}"
    partes = [f"DRIVER={{{driver}}}", f"SERVER={servidor}", f"DATABASE={c.banco}",
              f"UID={c.usuario}", f"PWD={{{c.senha}}}", "ApplicationIntent=ReadOnly"]
    if "ODBC Driver 1" in driver:          # 17/18: aceita certificado local sem configurar nada
        partes += ["Encrypt=optional", "TrustServerCertificate=yes"]
    return ";".join(partes)


def conectar(c: ConexaoSqlServer):
    pyodbc = _pyodbc()
    con = pyodbc.connect(string_conexao(c), timeout=15, readonly=True) if _aceita_readonly(pyodbc) \
        else pyodbc.connect(string_conexao(c), timeout=15)
    return con


def _aceita_readonly(pyodbc) -> bool:
    versao = tuple(int(x) for x in pyodbc.version.split(".")[:2] if x.isdigit())
    return versao >= (4, 0)


def diagnostico(con) -> dict:
    cur = con.cursor()
    info = {"avisos": [], "tabelas": {}}
    try:
        cur.execute("SELECT @@VERSION")
        info["versao"] = (cur.fetchone()[0] or "").splitlines()[0]
    except Exception:                       # outro ODBC (ex.: testes)
        info["versao"] = "conectado via ODBC"
    for tabela in ("SECAO", "GRUPO", "SUBGRUPO", "PRODUTO", "CLIENTE", "FORNECEDOR"):
        try:
            cur.execute(f"SELECT COUNT(*) FROM {tabela}")
            info["tabelas"][tabela] = cur.fetchone()[0]
        except Exception:
            info["tabelas"][tabela] = None
    return info


def mensagem_amigavel(erro: Exception) -> str:
    t = str(erro)
    if "Login failed" in t or "18456" in t:
        return "Usuario ou senha do SQL Server incorretos."
    if "Cannot open database" in t or "4060" in t:
        return "O banco informado nao existe no SQL Server (ou o usuario nao tem acesso a ele)."
    if "08001" in t or "TCP Provider" in t or "Named Pipes" in t or "Login timeout" in t:
        return ("Nao consegui chegar ao SQL Server: confira host, porta (padrao 1433) ou instancia, "
                "se o servico esta rodando e se o TCP/IP esta habilitado no SQL Server Configuration Manager.")
    if "IM002" in t or "Data source name not found" in t:
        return "Driver ODBC nao encontrado: deixe o campo driver vazio ou instale o ODBC Driver 18 for SQL Server."
    return t
