"""
Recria a pasta do migrador Python (migrador_syspdv_varejo) a partir de
assets/migrador_syspdv_varejo.json (todos os arquivos do projeto num arquivo so,
porque o pacote da skill nao aceita muitos arquivos nem zip dentro de zip).

Uso:  python3 scripts/recriar_migrador.py /tmp            -> cria /tmp/migrador_syspdv_varejo
      python3 scripts/recriar_migrador.py /tmp --listar   -> so lista os arquivos
"""
import json
import sys
from pathlib import Path

PACOTE = Path(__file__).resolve().parent.parent / "assets" / "migrador_syspdv_varejo.json"


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    dados = json.loads(PACOTE.read_text(encoding="utf-8"))
    if "--listar" in sys.argv:
        print("\n".join(sorted(dados["arquivos"])))
        return
    raiz = Path(sys.argv[1]).expanduser() / "migrador_syspdv_varejo"
    for caminho, conteudo in dados["arquivos"].items():
        destino = raiz / caminho
        destino.parent.mkdir(parents=True, exist_ok=True)
        destino.write_bytes(conteudo.encode("utf-8"))   # bytes: preserva \r\n dos .bat/.ps1
        if destino.suffix == ".sh":
            destino.chmod(0o755)
    for pasta in dados.get("pastas_vazias", []):
        (raiz / pasta).mkdir(parents=True, exist_ok=True)
    print(f"{len(dados['arquivos'])} arquivos recriados em {raiz} (versao {dados['versao']})")
    print("Faltam so as DLLs do client Firebird 64 bits: ver windows/firebird_client_x64/LEIA-ME.txt")


if __name__ == "__main__":
    main()
