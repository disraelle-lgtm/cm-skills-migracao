"""
Descobre o container do Firebird no Docker: porta publicada e volumes (pasta host -> container).
Funciona no Linux e no Windows (Docker Desktop), desde que o comando `docker` esteja disponivel.
"""
import json
import os
import re
import shutil
import subprocess


class ErroDocker(Exception):
    pass


def _docker(*args: str, timeout: int = 20) -> str:
    if not shutil.which("docker"):
        raise ErroDocker("Comando 'docker' não encontrado neste computador.")
    try:
        r = subprocess.run(["docker", *args], capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise ErroDocker("O Docker não respondeu. Confira se o serviço está rodando.") from None
    if r.returncode != 0:
        msg = r.stderr.strip()
        if "permission denied" in msg.lower():
            raise ErroDocker("Sem permissão para usar o Docker. Rode "
                             "'sudo usermod -aG docker $USER' e faça logout/login.")
        if "cannot connect" in msg.lower() or "is the docker daemon running" in msg.lower():
            raise ErroDocker("O serviço do Docker não está rodando.")
        raise ErroDocker(msg or "falha ao executar o docker")
    return r.stdout


def listar_containers_firebird() -> list[dict]:
    """Containers EM EXECUCAO cuja imagem ou nome contem 'firebird'."""
    encontrados = []
    for linha in _docker("ps", "--format", "{{json .}}").splitlines():
        if not linha.strip():
            continue
        d = json.loads(linha)
        if "firebird" in (d.get("Image", "") + d.get("Names", "")).lower():
            encontrados.append({"nome": d["Names"], "imagem": d["Image"],
                                "status": d.get("Status", "")})
    return encontrados


def _caminho_host(source: str) -> str:
    # Docker Desktop no Windows informa C:\dados como /run/desktop/mnt/host/c/dados
    m = re.match(r"^/run/desktop/mnt/host/([a-zA-Z])/(.*)$", source)
    if m:
        return f"{m.group(1).upper()}:\\" + m.group(2).replace("/", "\\")
    return source


def _dentro(caminho: str, pasta: str) -> bool:
    c = os.path.normcase(os.path.normpath(caminho))
    p = os.path.normcase(os.path.normpath(pasta))
    return c.startswith(p.rstrip(os.sep) + os.sep)


def inspecionar(nome: str, caminho_fdb: str | None = None) -> dict:
    """Retorna host/porta para conectar e o volume que contem o .FDB (se houver)."""
    dados = json.loads(_docker("inspect", nome))[0]

    montagens = [{"host": _caminho_host(m["Source"]), "container": m["Destination"]}
                 for m in dados.get("Mounts", []) if m.get("Source") and m.get("Destination")]

    escolhida = None
    if caminho_fdb:  # o volume mais especifico que contem o arquivo escolhido
        candidatas = [m for m in montagens if _dentro(caminho_fdb, m["host"])]
        if candidatas:
            escolhida = max(candidatas, key=lambda m: len(m["host"]))
    if escolhida is None and montagens:
        provaveis = [m for m in montagens
                     if any(t in m["container"].lower() for t in ("firebird", "data", "dados", "db"))]
        escolhida = (provaveis or montagens)[0]

    rede = dados.get("NetworkSettings") or {}
    publicada = (rede.get("Ports") or {}).get("3050/tcp") or []
    if publicada:
        host, porta = "localhost", publicada[0]["HostPort"]
    else:
        # Sem porta publicada: no Linux da para acessar pelo IP interno do container
        ips = [n.get("IPAddress") for n in (rede.get("Networks") or {}).values() if n.get("IPAddress")]
        host, porta = (ips[0] if ips else "localhost"), "3050"

    imagem = dados.get("Config", {}).get("Image", "")
    return {
        "nome": nome,
        "imagem": imagem,
        "parece_2_5": "2.5" in imagem or "2_5" in imagem,
        "host": host,
        "porta": str(porta),
        "porta_publicada": bool(publicada),
        "montagens": montagens,
        "montagem": escolhida,
    }
