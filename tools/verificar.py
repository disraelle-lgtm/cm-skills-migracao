"""
Checagens antes do commit / no PR (o GitHub Actions roda o mesmo):
  1. JSON do app em dia com migrador_syspdv_varejo/
  2. VERSAO do app citada no SKILL.md e na secao 11 da referencia
  3. manifestos validos e SKILL.md com frontmatter (name igual ao da pasta)
  4. nenhum bin/ no topo do plugin (o sync da organizacao rejeita)
  5. regra de seguranca: nada que pareca CNPJ ou credencial nos arquivos de texto da skill
Uso:  python tools/verificar.py
"""
import json
import re
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PLUGIN = RAIZ / "plugins/migracao-dados-cm"
SKILL = PLUGIN / "skills/migracao-dados-cm"
erros: list[str] = []

r = subprocess.run([sys.executable, str(RAIZ / "tools/empacotar_migrador.py"), "--conferir"],
                   capture_output=True, text=True)
if r.returncode:
    erros.append((r.stderr or r.stdout).strip())

v = json.loads((SKILL / "assets/migrador_syspdv_varejo.json").read_text(encoding="utf-8"))["versao"]
if f"versão {v}" not in (SKILL / "SKILL.md").read_text(encoding="utf-8"):
    erros.append(f"SKILL.md não cita a versão atual do migrador ({v})")
if f'VERSAO = "{v}"' not in (SKILL / "references/migrador_python_syspdv_varejo.md").read_text(encoding="utf-8"):
    erros.append(f"references/migrador_python_syspdv_varejo.md (seção 11) não cita VERSAO = \"{v}\"")

for f in (RAIZ / ".claude-plugin/marketplace.json", PLUGIN / ".claude-plugin/plugin.json"):
    try:
        json.loads(f.read_text(encoding="utf-8"))
    except Exception as e:
        erros.append(f"{f.relative_to(RAIZ)} inválido: {e}")
m = re.match(r'---\s*\nname:\s*"?([^"\n]+)"?\s*\ndescription:', (SKILL / "SKILL.md").read_text(encoding="utf-8"))
if not m or m.group(1) != SKILL.name:
    erros.append("SKILL.md sem frontmatter válido ou name diferente da pasta")
if (PLUGIN / "bin").exists():
    erros.append("plugins/migracao-dados-cm/bin/ não é aceito pelo sync da organização: use scripts/")

CNPJ = re.compile(r"\b\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}\b")
SENHA = re.compile(r"(?i)\b(password|senha|pwd)\s*[=:]\s*['\"][^'\"\s]{4,}['\"]")
for p in SKILL.rglob("*"):
    if p.is_file() and p.suffix.lower() in {".md", ".csv", ".sql", ".py", ".txt"}:
        t = p.read_text(encoding="utf-8", errors="ignore")
        for rx, nome in ((CNPJ, "CNPJ"), (SENHA, "possível senha")):
            if rx.search(t):
                erros.append(f"{nome} em {p.relative_to(RAIZ)} — usar placeholder")

if erros:
    print("FALHOU:\n- " + "\n- ".join(erros))
    sys.exit(1)
print(f"OK — migrador {v}, skill pronta para o merge")
