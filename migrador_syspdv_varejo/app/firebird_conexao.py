"""
Conexao com o SysPDV (Firebird), trazida do migrador_auto e unificada com o modo
arquivo que o app ja tinha:

- SERVIDOR (local ou Docker): conecta via TCP em host/porta. No Docker, o caminho
  do .FDB escolhido no computador e traduzido para o caminho DENTRO do container
  usando o volume (pasta no host -> pasta no container).
- ARQUIVO (upload): abre o .fdb enviado pelo caminho local, como o app ja fazia.

Nos dois casos:
- o fbclient e localizado automaticamente e so e usado se REALMENTE carregar
  (o client 2.5 de /opt/firebird exige libncurses5, ausente no Ubuntu 24.04;
  o client 3.0 do sistema - pacote libfbclient2 - conecta em servidor 2.5);
- o charset da conexao e configuravel (o SysPDV costuma ser WIN1252; abrir como
  UTF8 um banco NONE/WIN1252 quebra a acentuacao);
- a transacao e SOMENTE LEITURA: o migrador nunca altera a origem.
"""
from __future__ import annotations

import ctypes
import logging
import os
import sys
from dataclasses import dataclass

log = logging.getLogger("migrador.firebird")
WINDOWS = sys.platform.startswith("win")
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Client 64 bits que o instalar.bat baixa quando o Firebird instalado e 32 bits
CLIENT_LOCAL_X64 = os.path.join(RAIZ, "windows", "firebird_client_x64", "fbclient.dll")
CLIENT_LOCAL_X64_ANTIGO = os.path.join(RAIZ, "firebird_client_x64", "fbclient.dll")  # versoes anteriores
_PASTAS_DLL = []  # mantem os os.add_dll_directory ativos
_PASTAS_ADICIONADAS: set = set()

CANDIDATOS_FBCLIENT = {
    "win32": [  # o Python do migrador e 64 bits: os de 64 bits vem primeiro
        r"C:\Program Files\Firebird\Firebird_2_5\bin\fbclient.dll",
        CLIENT_LOCAL_X64,
        CLIENT_LOCAL_X64_ANTIGO,
        r"C:\Program Files\Firebird\Firebird_3_0\fbclient.dll",
        r"C:\Program Files (x86)\Firebird\Firebird_2_5\bin\fbclient.dll",
        r"C:\Program Files (x86)\Firebird\Firebird_3_0\fbclient.dll",
    ],
    "linux": [
        "/usr/lib/x86_64-linux-gnu/libfbclient.so.2",
        "/usr/lib/aarch64-linux-gnu/libfbclient.so.2",
        "/usr/lib64/libfbclient.so.2",
        "/usr/lib/libfbclient.so.2",
        "/opt/firebird/lib/libfbclient.so.2",
        "/opt/firebird/lib/libfbclient.so",
    ],
}
CHARSETS = ["WIN1252", "ISO8859_1", "UTF8", "NONE"]


def _erro_ao_carregar(caminho: str) -> str | None:
    if WINDOWS and hasattr(os, "add_dll_directory"):
        # o fbclient.dll precisa achar as DLLs que estao ao lado dele (msvcr80, icu...)
        pasta = os.path.dirname(os.path.abspath(caminho))
        if pasta not in _PASTAS_ADICIONADAS and os.path.isdir(pasta):
            try:
                _PASTAS_DLL.append(os.add_dll_directory(pasta))
                _PASTAS_ADICIONADAS.add(pasta)
            except OSError:
                pass
    try:
        ctypes.CDLL(caminho)
        return None
    except OSError as erro:
        return str(erro)


def localizar_fbclient(configurado: str | None = None) -> str | None:
    """Caminho informado (validado) ou o primeiro fbclient do sistema que carrega."""
    falhas = []
    if configurado:
        if not os.path.exists(configurado):
            raise FileNotFoundError(f"fbclient informado nao existe: {configurado}")
        erro = _erro_ao_carregar(configurado)
        if erro is None:
            return configurado
        # ex.: Windows com Firebird 32 bits e Python 64 bits (WinError 193). Em vez de parar,
        # tenta os client que vem com o migrador / instalados; avisa no log.
        log.warning("fbclient informado nao carregou (%s): %s - procurando outro", configurado, erro)
        falhas.append(f"{configurado}: {erro}")
    for caminho in CANDIDATOS_FBCLIENT["win32" if WINDOWS else "linux"]:
        if not os.path.exists(caminho):
            continue
        erro = _erro_ao_carregar(caminho)
        if erro is None:
            return caminho
        falhas.append(f"{caminho}: {erro}")
        log.warning("Ignorando fbclient que nao carrega: %s (%s)", caminho, erro)
    if falhas:
        if any("193" in f or "not a valid Win32" in f or "aplicativo Win32" in f for f in falhas):
            raise OSError("WinError 193: o fbclient.dll e de 32 bits e o Python do migrador e de 64 bits, "
                          "e nao achei o client 64 bits (pasta windows\\firebird_client_x64 do migrador). "
                          + " | ".join(falhas))
        raise OSError("Nenhum fbclient utilizavel. " + " | ".join(falhas))
    return None  # deixa o fdb procurar sozinho (PATH / ldconfig)


def traduzir_caminho(caminho: str, pasta_host: str | None, pasta_container: str | None) -> str:
    """Caminho do .FDB no computador -> caminho dentro do container (volume)."""
    if not pasta_host or not pasta_container:
        raise ValueError("No modo Docker, informe a pasta no host e a pasta no container "
                         "(o volume). Use o botao Detectar.")
    pc = pasta_container.replace("\\", "/").rstrip("/")
    normal = caminho.replace("\\", "/")
    if normal.startswith(pc + "/"):
        return normal  # ja e o caminho do container
    ch = os.path.normcase(os.path.normpath(caminho))
    ph = os.path.normcase(os.path.normpath(pasta_host)).rstrip(os.sep)
    if not ch.startswith(ph + os.sep):
        raise ValueError(f"O arquivo nao esta dentro da pasta mapeada no container ({pasta_host}).")
    relativo = os.path.relpath(os.path.normpath(caminho), os.path.normpath(pasta_host))
    return f"{pc}/{relativo.replace(os.sep, '/')}"


@dataclass
class ConexaoServidor:
    """Dados de conexao com um servidor Firebird (local ou Docker)."""
    host: str = "localhost"
    porta: int = 3050
    caminho: str = ""            # caminho do .FDB como voce ve no computador
    usuario: str = "SYSDBA"
    senha: str = ""
    charset: str = "WIN1252"
    fbclient: str | None = None
    modo: str = "local"          # "local" | "docker"
    pasta_host: str | None = None
    pasta_container: str | None = None

    @property
    def caminho_servidor(self) -> str:
        if self.modo == "docker":
            return traduzir_caminho(self.caminho, self.pasta_host, self.pasta_container)
        return self.caminho

    @property
    def dsn(self) -> str:
        return f"{self.host}/{self.porta}:{self.caminho_servidor}"


def _abrir(dsn: str, usuario: str, senha: str, charset: str, fbclient: str | None):
    import fdb
    kwargs = dict(dsn=dsn, user=usuario, password=senha, charset=charset,
                  isolation_level=fdb.ISOLATION_LEVEL_READ_COMMITED_RO)
    client = localizar_fbclient(fbclient)
    if client:
        kwargs["fb_library_name"] = client
    return fdb.connect(**kwargs)


def conectar_servidor(c: ConexaoServidor):
    log.info("Conectando no Firebird: %s", c.dsn)
    return _abrir(c.dsn, c.usuario, c.senha, c.charset, c.fbclient)


def conectar_arquivo(caminho: str, usuario: str = "SYSDBA", senha: str = "masterkey",
                     charset: str = "WIN1252", fbclient: str | None = None):
    """Arquivo enviado por upload (sem host no DSN: embarcado/local)."""
    return _abrir(caminho, usuario, senha, charset, fbclient)


def diagnostico(con) -> dict:
    """Versao, charset e contagens usadas no botao Testar."""
    cur = con.cursor()
    cur.execute("SELECT RDB$GET_CONTEXT('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
    versao = cur.fetchone()[0]
    cur.execute("SELECT RDB$CHARACTER_SET_NAME FROM RDB$DATABASE")
    charset = (cur.fetchone()[0] or "NONE").strip()
    contagens = {}
    for tabela in ("SECAO", "GRUPO", "SUBGRUPO", "PRODUTO", "CLIENTE", "FORNECEDOR"):
        try:
            cur.execute(f"SELECT COUNT(*) FROM {tabela}")
            contagens[tabela] = cur.fetchone()[0]
        except Exception:
            contagens[tabela] = None
    avisos = []
    if not str(versao).startswith("2.5"):
        avisos.append(f"Servidor Firebird {versao}: o padrao do SysPDV e 2.5. Confira se e o servidor certo.")
    return {"versao": versao, "charset_banco": charset, "contagens": contagens, "avisos": avisos}


def aviso_permissao(caminho_host: str) -> str | None:
    """No Linux o servidor Firebird roda com outro usuario: precisa de leitura+escrita."""
    if WINDOWS or not caminho_host or not os.path.exists(caminho_host):
        return None
    modo = os.stat(caminho_host).st_mode
    if modo & 0o006 != 0o006:
        return (f"O servidor Firebird pode nao conseguir abrir o arquivo (permissao "
                f"{oct(modo & 0o777)}). Se der erro de I/O: chmod 666 \"{caminho_host}\"")
    return None


def mensagem_amigavel(erro: Exception) -> str:
    t = str(erro)
    if "libncurses.so.5" in t or "libtinfo.so.5" in t:
        return ("O fbclient do Firebird 2.5 (/opt/firebird) precisa da libncurses5, que o Ubuntu "
                "24.04 nao tem. Instale o client do sistema: sudo apt install libfbclient2 "
                "(o migrador passa a usa-lo sozinho).")
    if "WinError 193" in t or "not a valid Win32" in t or "aplicativo Win32" in t:
        return ("O fbclient.dll informado e de 32 bits (Firebird 32 bits) e o migrador e 64 bits. "
                "Deixe o campo fbclient VAZIO: o migrador usa o client 64 bits da pasta "
                "windows\\firebird_client_x64. Se ela nao existir, extraia o zip do migrador de novo.")
    if "Client Library" in t:
        return ("Nao encontrei o client do Firebird. " +
                ("Instale o client do Firebird 2.5 (mesma arquitetura do Python) ou informe o "
                 "fbclient.dll." if WINDOWS else "No Ubuntu: sudo apt install libfbclient2."))
    if "Unable to complete network request" in t:
        return "Servidor Firebird nao respondeu. Confira host, porta e se o servico/container esta rodando."
    if "user name and password are not defined" in t:
        return "Usuario ou senha do Firebird incorretos."
    if "I/O error" in t or "open file" in t:
        return ("O servidor nao conseguiu abrir o .FDB: caminho errado ou sem permissao. No Docker o "
                "caminho tem que ser o de dentro do container; no Linux o arquivo precisa de chmod 666.")
    return t
