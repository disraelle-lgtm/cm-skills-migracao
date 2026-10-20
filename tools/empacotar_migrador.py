"""
Gera o assets/migrador_syspdv_varejo.json da skill a partir do codigo do app em
migrador_syspdv_varejo/ (a pasta de verdade, editada no repositorio).

O pacote da skill nao aceita muitos arquivos nem zip, por isso o app vai para a skill
como um JSON unico; a skill o recria com scripts/recriar_migrador.py.

Uso (na raiz do repositorio):
    python tools/empacotar_migrador.py            -> regrava o JSON
    python tools/empacotar_migrador.py --conferir -> so confere se o JSON esta em dia (exit 1 se nao)
"""
import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
APP = RAIZ / "migrador_syspdv_varejo"
JSON = RAIZ / "plugins/migracao-dados-cm/skills/migracao-dados-cm/assets/migrador_syspdv_varejo.json"

# fora do pacote: binarios do client Firebird, caches e saidas de execucao
IGNORAR_PASTAS = {"__pycache__", ".venv", "venv", ".pytest_cache"}
IGNORAR_SUFIXOS = {".dll", ".exe", ".msi", ".zip", ".pyc", ".log"}
PASTAS_VAZIAS = ["reports"]          # recriadas vazias (relatorios de cada execucao)


def versao() -> str:
    m = re.search(r'^VERSAO\s*=\s*"([^"]+)"', (APP / "app/main.py").read_text(encoding="utf-8"), re.M)
    if not m:
        sys.exit("VERSAO nao encontrada em migrador_syspdv_varejo/app/main.py")
    return m.group(1)


def arquivos() -> dict:
    saida = {}
    for p in sorted(APP.rglob("*")):
        rel = p.relative_to(APP)
        if not p.is_file() or set(rel.parts) & IGNORAR_PASTAS or p.suffix.lower() in IGNORAR_SUFIXOS:
            continue
        if rel.parts[0] in PASTAS_VAZIAS and p.name != ".gitkeep":
            continue
        try:
            saida[rel.as_posix()] = p.read_bytes().decode("utf-8")   # bytes: preserva \r\n de .bat/.ps1
        except UnicodeDecodeError:
            sys.exit(f"Arquivo nao-texto no app (nao cabe no JSON): {rel}")
    return saida


def montar() -> dict:
    v = versao()
    return {
        "_leia_me": (f"Projeto migrador_syspdv_varejo (versao {v}) em um arquivo so. Recrie a pasta com: "
                     "python3 scripts/recriar_migrador.py <destino>. Sem as DLLs do client Firebird "
                     "(ver windows/firebird_client_x64/LEIA-ME.txt e a secao 10 da referencia). "
                     "GERADO por tools/empacotar_migrador.py - nao editar a mao."),
        "versao": v,
        "pastas_vazias": PASTAS_VAZIAS,
        "arquivos": arquivos(),
    }


def main() -> None:
    novo = montar()
    if "--conferir" in sys.argv:
        atual = json.loads(JSON.read_text(encoding="utf-8"))
        if atual.get("arquivos") != novo["arquivos"] or atual.get("versao") != novo["versao"]:
            sys.exit("assets/migrador_syspdv_varejo.json DESATUALIZADO: rode python tools/empacotar_migrador.py")
        print(f"JSON em dia com migrador_syspdv_varejo/ (versao {novo['versao']}, {len(novo['arquivos'])} arquivos)")
        return
    JSON.write_text(json.dumps(novo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{JSON.relative_to(RAIZ)} regravado: versao {novo['versao']}, {len(novo['arquivos'])} arquivos")


if __name__ == "__main__":
    main()
