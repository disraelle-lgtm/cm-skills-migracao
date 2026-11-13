"""Configuração e conexão com Firebird e SQL Server.

Senhas NUNCA ficam no arquivo de configuração: o JSON só guarda o NOME da variável
de ambiente (senha_env). Os drivers são importados só quando necessários, então quem
usa apenas Firebird não precisa do pyodbc (e vice-versa).
"""
from __future__ import annotations

import json
import os
from pathlib import Path

PASTA = Path(__file__).resolve().parent
TIPOS = ("firebird", "sqlserver", "postgres")
USOS = ("leitura", "migracao")

PADROES = {
    "limite_linhas_padrao": 200,
    "limite_linhas_maximo": 1000,
    "timeout_segundos": 30,
    "mascarar_colunas": ["SENHA", "PASSWORD", "PWD", "TOKEN", "SECRET", "CHAVE_API"],
    # --- migração (aprovação humana) ---
    "app_url": "http://127.0.0.1:8020",       # migrador em execução (só endereço local)
    "aprovacao_validade_minutos": 15,
    "max_itens_por_aprovacao": 1,             # 1 = uma etapa por aprovação
}


class ErroConfig(Exception):
    pass


def caminho_config() -> Path:
    return Path(os.environ.get("MCP_BANCOS_CONFIG") or PASTA / "conexoes.json")


def carregar_config(caminho: Path | None = None) -> dict:
    caminho = caminho or caminho_config()
    if not caminho.exists():
        raise ErroConfig(
            f"Arquivo de configuração não encontrado: {caminho}. "
            "Copie conexoes.exemplo.json para conexoes.json e ajuste."
        )
    try:
        dados = json.loads(caminho.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as e:
        raise ErroConfig(f"{caminho.name} não é um JSON válido: {e}") from e
    conexoes = dados.get("conexoes")
    if not isinstance(conexoes, dict) or not conexoes:
        raise ErroConfig("A configuração precisa ter ao menos uma entrada em 'conexoes'.")
    for nome, c in conexoes.items():
        if c.get("tipo") not in TIPOS:
            raise ErroConfig(f"Conexão '{nome}': 'tipo' deve ser um de {TIPOS}.")
        if "senha" in c:
            raise ErroConfig(
                f"Conexão '{nome}': não grave a senha no arquivo. Use 'senha_env' com o nome de uma variável de ambiente."
            )
        if not c.get("banco"):
            raise ErroConfig(f"Conexão '{nome}': falta 'banco'.")
        if c.get("uso", "leitura") not in USOS:
            raise ErroConfig(f"Conexão '{nome}': 'uso' deve ser um de {USOS}.")
    cfg = {**PADROES, **{k: v for k, v in dados.items() if k != "conexoes"}}
    cfg["conexoes"] = conexoes
    cfg["limite_linhas_maximo"] = max(1, int(cfg["limite_linhas_maximo"]))
    cfg["limite_linhas_padrao"] = min(max(1, int(cfg["limite_linhas_padrao"])), cfg["limite_linhas_maximo"])
    cfg["aprovacao_validade_minutos"] = min(max(1, int(cfg["aprovacao_validade_minutos"])), 240)
    cfg["max_itens_por_aprovacao"] = max(1, int(cfg["max_itens_por_aprovacao"]))
    return cfg


def senha_de(nome: str, c: dict) -> str:
    """Lê a senha da variável de ambiente indicada em 'senha_env'."""
    var = c.get("senha_env")
    if not var:
        raise ErroConfig(f"Conexão '{nome}': falta 'senha_env' (nome da variável de ambiente com a senha).")
    valor = os.environ.get(var)
    if valor is None:
        raise ErroConfig(f"Conexão '{nome}': a variável de ambiente {var} não está definida.")
    return valor


# ---------------------------------------------------------------- Firebird
_fb_api_carregada = False


def _conectar_firebird(nome: str, c: dict):
    global _fb_api_carregada
    import fdb  # noqa: WPS433 (import tardio de propósito)

    lib = c.get("fbclient") or os.environ.get("MCP_FBCLIENT")
    if lib and not _fb_api_carregada:
        fdb.load_api(lib)
        _fb_api_carregada = True
    return fdb.connect(
        host=c.get("host", "localhost"),
        port=int(c.get("porta", 3050)),
        database=c["banco"],
        user=c.get("usuario", "SYSDBA"),
        password=senha_de(nome, c),
        charset=c.get("charset", "WIN1252"),
        isolation_level=fdb.ISOLATION_LEVEL_READ_COMMITED_RO,  # transação somente leitura
    )


# --------------------------------------------------------------- SQL Server
def _escapar_odbc(valor: str) -> str:
    return "{" + str(valor).replace("}", "}}") + "}"


def _conectar_sqlserver(nome: str, c: dict, timeout: int):
    import pyodbc

    driver = c.get("driver")
    if not driver:
        instalados = [d for d in pyodbc.drivers() if "SQL Server" in d]
        preferidos = [d for d in instalados if "ODBC Driver" in d]
        if not instalados:
            raise ErroConfig("Nenhum driver ODBC do SQL Server instalado. Instale o 'ODBC Driver 17/18 for SQL Server'.")
        driver = sorted(preferidos or instalados)[-1]
    servidor = c.get("host", "localhost")
    if c.get("porta"):
        servidor = f"{servidor},{int(c['porta'])}"
    partes = [f"DRIVER={_escapar_odbc(driver)}", f"SERVER={servidor}", f"DATABASE={_escapar_odbc(c['banco'])}"]
    if c.get("autenticacao") == "windows":
        partes.append("Trusted_Connection=yes")
    else:
        partes += [f"UID={_escapar_odbc(c.get('usuario', ''))}", f"PWD={_escapar_odbc(senha_de(nome, c))}"]
    if c.get("confiar_certificado"):
        partes.append("TrustServerCertificate=yes")
    partes.append("ApplicationIntent=ReadOnly")
    conn = pyodbc.connect(";".join(partes), timeout=timeout, autocommit=False)
    conn.timeout = timeout  # tempo máximo por consulta
    return conn


# --------------------------------------------------------------- PostgreSQL
def _conectar_postgres(nome: str, c: dict, timeout: int):
    import psycopg

    con = psycopg.connect(
        host=c.get("host", "localhost"),
        port=int(c.get("porta", 5432)),
        dbname=c["banco"],
        user=c.get("usuario", "postgres"),
        password=senha_de(nome, c),
        connect_timeout=10,
        application_name="mcp_migrador_leitura",
        # duas travas: o servidor recusa escrita e a consulta tem tempo máximo
        options=f"-c default_transaction_read_only=on -c statement_timeout={int(timeout) * 1000}",
    )
    con.read_only = True
    return con


def conectar(nome: str, c: dict, timeout: int):
    if c["tipo"] == "firebird":
        return _conectar_firebird(nome, c)
    if c["tipo"] == "postgres":
        return _conectar_postgres(nome, c, timeout)
    return _conectar_sqlserver(nome, c, timeout)
