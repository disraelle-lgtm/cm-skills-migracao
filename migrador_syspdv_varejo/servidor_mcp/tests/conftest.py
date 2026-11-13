"""Migrador FALSO (HTTP local) para testar o MCP sem bancos e sem o app real."""
import json, pathlib, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from types import SimpleNamespace
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
import pytest


def mod(id_, nome, grupo, descricao="", **kw):
    base = {"id": id_, "nome": nome, "grupo": grupo, "descricao": descricao, "pasta": f"comandos/{id_}",
            "etapas": [{"id": id_, "nome": nome, "arquivos": ["inserir.sql"]}], "arquivos": ["inserir.sql"],
            "problemas": [], "automatico_com_grupo": None, "automatico_sempre": False, "opcoes": []}
    base.update(kw)
    return base


MODULOS = {
    "inicial": [
        mod("01_secao", "Seção", "Cadastros Padrão"),
        mod("02_grupo", "Grupo", "Cadastros Padrão"),
        mod("09_cliente", "Cliente", "Cadastro de Pessoas"),
        mod("19_ajustes_pessoas", "Ajustes finais de Pessoas", "Cadastro de Pessoas", automatico_com_grupo="Cadastro de Pessoas"),
        mod("50_quebrado", "Quebrado", "Financeiro", problemas=["falta origem.sql"]),
        mod("99_fila_panama", "Fila de sincronização do Panamá", "Finalização",
            "apaga fila_sincronizacao e fila_sincronizacao_panama e recria", automatico_sempre=True),
    ],
    "virada": [
        mod("20_virada_codigos_produto", "Virada de códigos de produto", "Produto"),
        mod("99_fila_panama", "Fila de sincronização do Panamá", "Finalização", automatico_sempre=True),
    ],
}


class Fake:
    def __init__(self):
        self.chamadas = []                 # (metodo, caminho, corpo)
        self.migrar_resposta = None        # (codigo, corpo) para forçar erro
        self.status = {"id": "EX1", "status": "em_andamento", "simulacao": True, "erro": None, "banco": "vf",
                       "tempo_total": 1.5, "total_log": 3, "log": ["a", "b", "c"],
                       "modulos": {"01_secao": {"nome": "Seção", "status": "rodando", "lidos": 10, "inseridos": 0,
                                                "atualizados": 0, "sem_alteracao": 0, "pulados": 0, "erros": 0,
                                                "duracao": 0.2, "mensagem": None, "inicio_ts": 1.0}}}

    def posts(self, caminho):
        return [c for c in self.chamadas if c[0] == "POST" and c[1] == caminho]


def _handler(fake: Fake):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _json(self, codigo, obj):
            dados = json.dumps(obj).encode()
            self.send_response(codigo)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(dados)))
            self.end_headers()
            self.wfile.write(dados)

        def do_GET(self):
            u = urlparse(self.path)
            fake.chamadas.append(("GET", u.path, None))
            if u.path == "/saude":
                return self._json(200, {"app": "migrador_syspdv_varejo", "pasta": "C:/x", "versao": "2026.10.31", "sistema": "windows"})
            if u.path == "/modulos":
                conj = parse_qs(u.query).get("conjunto", ["inicial"])[0]
                return self._json(200, MODULOS[conj]) if conj in MODULOS else self._json(400, {"detail": "conjunto inválido"})
            if u.path.startswith("/status/"):
                return self._json(200, fake.status)
            if u.path.startswith("/codigos/status/"):
                return self._json(200, {"status": "concluido", "log": ["ok"], "total_log": 1, "resultado": {"x": 1}, "erro": None})
            self._json(404, {"detail": "não existe"})

        def do_POST(self):
            u = urlparse(self.path)
            corpo = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            fake.chamadas.append(("POST", u.path, corpo))
            if u.path == "/migrar":
                if fake.migrar_resposta:
                    return self._json(*fake.migrar_resposta)
                return self._json(200, {"exec_id": "EX1"})
            if u.path == "/codigos/consultar":
                return self._json(200, {"clientes": {"quantidade": 2, "menor": 999999, "maior": 1000001}})
            if u.path == "/codigos/ajustar":
                return self._json(200, {"ajuste_id": "AJ1"})
            self._json(404, {"detail": "não existe"})
    return H


@pytest.fixture()
def fake_migrador():
    fake = Fake()
    srv = ThreadingHTTPServer(("127.0.0.1", 0), _handler(fake))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    fake.url = f"http://127.0.0.1:{srv.server_address[1]}"
    fake.parar = lambda: (srv.shutdown(), srv.server_close())
    yield fake
    try:
        srv.shutdown()
        srv.server_close()
    except Exception:
        pass


@pytest.fixture()
def amb_mig(tmp_path, monkeypatch, fake_migrador):
    import aprovacoes, migracao, server
    cfg = {
        "app_url": fake_migrador.url, "limite_linhas_padrao": 5, "limite_linhas_maximo": 8, "aprovacao_validade_minutos": 15,
        "conexoes": {
            "origem": {"tipo": "firebird", "uso": "leitura", "host": "srv", "porta": 3050, "banco": "C:\\d\\X.FDB",
                       "usuario": "LEITURA", "senha_env": "T_FB"},
            "pg_leitura": {"tipo": "postgres", "uso": "leitura", "host": "srv", "banco": "vf", "usuario": "leitura", "senha_env": "T_PGL"},
            "pg_destino": {"tipo": "postgres", "uso": "migracao", "host": "srv", "banco": "varejo_cli", "usuario": "postgres", "senha_env": "T_PG"},
        },
    }
    arq = tmp_path / "c.json"
    arq.write_text(json.dumps(cfg), encoding="utf-8")
    monkeypatch.setenv("MCP_BANCOS_CONFIG", str(arq))
    monkeypatch.setenv("T_FB", "senha-fb-secreta")
    monkeypatch.setenv("T_PG", "senha-pg-secreta")
    monkeypatch.setenv("T_PGL", "senha-pgl-secreta")
    monkeypatch.setattr(server, "AUDITORIA", tmp_path / "aud.log")
    monkeypatch.setattr(aprovacoes, "PASTA", tmp_path / "aprov")
    raiz = tmp_path / "app"
    for m in MODULOS["inicial"] + MODULOS["virada"]:
        (raiz / m["pasta"]).mkdir(parents=True, exist_ok=True)
        (raiz / m["pasta"] / "inserir.sql").write_text(f"-- {m['id']}\nINSERT INTO x VALUES (1);\n", encoding="utf-8")
    monkeypatch.setattr(migracao, "RAIZ_APP", raiz)
    return SimpleNamespace(fake=fake_migrador, raiz=raiz, tmp=tmp_path, cfg_arq=arq)
