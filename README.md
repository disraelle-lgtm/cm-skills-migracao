# cm-skills-migracao

Fonte única da skill **migracao-dados-cm** e do app **migrador_syspdv_varejo** (Casa Magalhães).
Este repositório é um *plugin marketplace*: a organização sincroniza o repositório com o Claude,
e cada merge na `main` chega a todos automaticamente. **Ninguém mais envia `.skill` por arquivo.**

## Estrutura

```
cm-skills-migracao/
├── .claude-plugin/marketplace.json          catálogo (lista os plugins deste repositório)
├── plugins/migracao-dados-cm/
│   ├── .claude-plugin/plugin.json           manifesto do plugin (sem "version": a versão é o commit)
│   └── skills/migracao-dados-cm/            a skill em si
│       ├── SKILL.md
│       ├── references/  scripts/
│       └── assets/migrador_syspdv_varejo.json   GERADO — não editar à mão
├── migrador_syspdv_varejo/                  código do app (arquivos reais — é aqui que se edita)
├── tools/
│   ├── empacotar_migrador.py                migrador_syspdv_varejo/  →  assets/…json
│   └── verificar.py                         checagens (também rodam no GitHub a cada PR)
├── .github/workflows/verificar.yml
├── CHANGELOG.md
├── .gitattributes                           preserva CRLF/LF do app (não remover)
└── .gitignore
```

Por que o app aparece duas vezes: o pacote da skill não aceita centenas de arquivos, então a skill
leva o app num JSON único. No repositório o app fica como arquivos normais, para que cada mudança
apareça linha a linha no diff e no review; o JSON é só a saída do `empacotar_migrador.py`.

## Configuração inicial (uma vez)

1. Criar o repositório **privado** `cm-skills-migracao` na organização GitHub da empresa e subir este conteúdo:
   ```bash
   git init -b main && git add . && git commit -m "Skill migracao-dados-cm e migrador 2026.10.25"
   git remote add origin git@github.com:<org-da-empresa>/cm-skills-migracao.git && git push -u origin main
   ```
2. Dar acesso de escrita aos mantenedores e proteger a `main` (merge só por pull request com a checagem `verificar` verde).
3. Um **owner da organização no Claude** abre *Organization settings > Plugins & skills*, escolhe
   sincronizar do GitHub, instala o Claude GitHub App no repositório e mantém a sincronização automática ligada.
4. Depois que o plugin aparecer para todos: desativar as cópias antigas enviadas à mão
   (`migracao-dados-cm` compartilhada e `migracao-dados-cm_Old`), para não haver duas skills com o mesmo nome.

## Dia a dia

```bash
git switch main && git pull
git switch -c ajuste/<descricao-curta>
```

**Mudou o app** (`migrador_syspdv_varejo/`):
1. Editar o código.
2. Subir `VERSAO` em `migrador_syspdv_varejo/app/main.py`.
3. `python tools/empacotar_migrador.py` — regenera o JSON da skill.
4. Atualizar a versão citada no `SKILL.md` e a seção 11 de `references/migrador_python_syspdv_varejo.md`
   (o que mudou e por quê).

**Mudou só a skill** (texto, referências, SQL): editar em `plugins/migracao-dados-cm/skills/migracao-dados-cm/`.

**Sempre:**
```bash
python tools/verificar.py          # tem que terminar em OK
# + uma linha no CHANGELOG.md
git add -A && git commit -m "<o que mudou>" && git push -u origin HEAD
```
Abrir o pull request; o outro mantenedor revisa e faz o merge. Depois do merge a organização sincroniza sozinha.

Gerar o pacote do app para instalar num cliente: zipar `migrador_syspdv_varejo/` (com as DLLs do
Firebird baixadas conforme `windows/firebird_client_x64/LEIA-ME.txt`).

## Regras

- **Nunca** colocar CNPJ, nome de cliente real, credenciais ou nomes de analistas ligados a casos reais —
  usar placeholders. O `verificar.py` barra CNPJ formatado e senhas literais, mas não pega tudo: o review é a segunda barreira.
- Não editar `assets/migrador_syspdv_varejo.json` à mão.
- Não criar pasta `bin/` dentro de `plugins/migracao-dados-cm/` (o sync da organização rejeita o plugin).
- Não pôr `"version"` no `plugin.json`: sem ela, cada commit novo já é uma versão nova; com ela, quem esquecer de subir o número trava a atualização para todos.

## Testar antes do merge (opcional, Claude Code)

```bash
claude plugin validate .
claude plugin marketplace add ./          # na raiz do clone
claude plugin install migracao-dados-cm@casa-magalhaes-dados
```
