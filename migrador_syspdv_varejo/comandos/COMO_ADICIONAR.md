# Como adicionar um novo item de migração

Cada pasta aqui dentro vira um **checkbox** na tela. A pasta guarda os comandos
daquela entidade: o SELECT no SysPDV, a transformação e os comandos no VarejoFacil.
Não precisa mexer no código do app nem reiniciar: crie a pasta e clique em
**Recarregar** na tela.

## 1. Os arquivos de uma pasta

| Arquivo | Onde roda | Obrigatório? | Para quê |
|---|---|---|---|
| `modulo.json` | — | não (recomendado) | Nome do checkbox, grupo, descrição e chave do relatório |
| `origem.sql` | Firebird (SysPDV) | **sim** | SELECT que traz as linhas a migrar |
| `transformar.py` | Python | não | Ajusta cada linha (TRIM, maiúsculo, código para número…) |
| `validar.sql` | PostgreSQL | não | Precisa devolver 1 linha; senão a linha vira erro (ex.: pai não existe) |
| `existe.sql` | PostgreSQL | não | Procura o registro no destino para decidir entre inserir e atualizar |
| `inserir.sql` | PostgreSQL | **sim** | INSERT do registro novo |
| `atualizar.sql` | PostgreSQL | não | UPDATE quando o registro existe e algum valor mudou |
| `antes.sql` / `depois.sql` | PostgreSQL | não | Rodam uma vez, antes/depois do item inteiro |
| `origem.sqlserver.sql` | SQL Server | não | Versão do `origem.sql` só para quando a origem é SQL Server (ex.: `LTRIM(RTRIM(x))` no lugar de `TRIM(x)`, que só existe no SQL Server 2017+). Sem ele, o `origem.sql` serve para os dois — escreva SQL comum aos dois bancos |
| `finalizar.sql` | PostgreSQL | não | Roda **sempre no fim da execução, mesmo se a migração parar com erro** — para desfazer algo que não pode ficar pela metade (ex.: religar triggers) |

**Item só de SQL**: uma pasta com apenas `modulo.json` + `depois.sql` (sem `origem.sql`) roda os comandos
uma vez — ex.: `19_ajustes_pessoas/`.

**Item automático (sem checkbox)**: com `"automatico_com_grupo": "Cadastro de Pessoas"` no
`modulo.json`, o item some da tela e roda sozinho, na ordem da pasta, sempre que algum item
daquele grupo for marcado — é assim que os Ajustes finais de Pessoas funcionam.

**Item automático em toda migração**: com `"automatico_sempre": true` no `modulo.json`, o item some
da tela e roda em TODA execução, na ordem da pasta (ex.: `99_fila_panama`, por último).

**Aviso no relatório**: se o `transformar.py` devolver a chave `"_aviso"`, o texto aparece na coluna
mensagem do relatório e não vai para o banco — ex.: o Cliente marca "cliente sem CPF/CNPJ".

O que acontece com **cada linha** do `origem.sql`:

```
origem.sql ──► transformar.py ──► validar.sql ──► existe.sql
                                                    │
                          não achou ◄───────────────┼──────────────► achou
                              │                                        │
                         inserir.sql                     algum valor mudou?
                         (inserido)                     sim: atualizar.sql (atualizado)
                                                        não: nada        (sem_alteracao)
```

Cada linha roda num *savepoint*: se uma der erro, só ela fica como "erro" no
relatório e as outras continuam. Se um arquivo inteiro der erro (ex.: coluna que não
existe), a migração para naquele item e avisa na tela.

## 2. Regras para escrever os comandos

- **Nomes das colunas do `origem.sql` chegam em minúsculo** no `transformar.py`:
  `SELECT SECCOD` → `linha["seccod"]`.
- **O dicionário que o `transformar.py` devolve** é o que os comandos do PostgreSQL
  enxergam. Um campo `"secdes"` vira `%(secdes)s` no SQL.
- **Sem `transformar.py`**, os nomes das colunas do `origem.sql` vão direto para o
  PostgreSQL. Funciona para casos simples, mas você perde o TRIM e as conversões.
- **No `existe.sql`**, devolva o id e as colunas que podem mudar. O motor compara
  cada coluna devolvida com o campo **de mesmo nome** do `transformar.py`. O id não
  existe no `transformar.py`, então não entra na comparação.
- **Comentários** começam com `--` e podem ficar em qualquer linha (são ignorados).
- **Sinal de por cento literal** dentro de um comando do PostgreSQL (ex.: `LIKE 'A%'`)
  precisa ser escrito em dobro: `LIKE 'A%%'`. No `origem.sql` (Firebird) não precisa.
- **Ordem**: os itens rodam pela ordem do nome da pasta. Use prefixo numérico
  (`01_`, `02_`…) e deixe intervalos (`10_`, `20_`) para encaixar itens depois.
- **Pastas que começam com `_`** (como `_modelo`) são ignoradas.

### Funções prontas para o `transformar.py`

```python
from app.ajudantes import inteiro, texto, numero, so_digitos, Pular

inteiro(" 001 ", "SECCOD")                  # 1   (vazio ou letra = erro da linha)
texto(" abc ", maiusculo=True)              # "ABC"
texto(None, vazio="RENOMEAR")               # "RENOMEAR"
texto("descricao longa", tamanho=10)        # "descricao "
numero("1.234,50")                          # Decimal("1234.50")
so_digitos("123.456.789-00")                # "12345678900"
raise Pular("cliente sem CPF")              # não migra a linha (fica "pulado")
```

## 3. Passo a passo para um item novo

1. **Copie a pasta `_modelo`** e renomeie com o número da ordem e o nome do item, por
   exemplo `04_nome_do_item`.
2. **Edite o `modulo.json`**: `nome` (texto do checkbox), `grupo` (título da seção na
   tela), `chave` (campos que identificam a linha no relatório).
3. **Escreva o `origem.sql`** com o SELECT no SysPDV. Teste antes no IBExpert ou no
   isql para ver se traz o que você espera.
4. **Escreva o `transformar.py`** devolvendo um dicionário com os nomes das colunas do
   VarejoFacil.
5. **Escreva o `inserir.sql`**, e o `existe.sql` + `atualizar.sql` se quiser que rodar
   de novo atualize em vez de duplicar.
6. **Apague os arquivos opcionais que não usar** (ex.: `validar.sql`, `antes.sql`).
7. Na tela: **Recarregar**, marque só o item novo e clique em Iniciar, numa **base de teste**
   (a migração grava de verdade). Confira o relatório "linha a linha"; rodar de novo é seguro
   (atualiza em vez de duplicar).

## 4. Traduzindo uma transformação do Pentaho para uma pasta

Os nomes reais de tabelas, colunas e sequences já estão nos `.ktr` do migrador Pentaho.
Abra a transformação no Spoon (ou leia o XML) e leve cada passo para o arquivo
correspondente:

| No Pentaho (.ktr) | Na pasta |
|---|---|
| Passo **Table input** da conexão SysPDV (SQL) | `origem.sql` |
| **String operations** (trim, upper), **Select values** (tipo Integer), **If field value is null**, **Add constants** | `transformar.py` |
| **Sequence** (nome da sequence) | `nextval('nome_da_sequence')` no `inserir.sql` |
| **Insert/Update** → tabela e campos | `inserir.sql` |
| **Insert/Update** → "The key(s) to look up the value(s)" | `WHERE` do `existe.sql` e do `atualizar.sql` |
| **Insert/Update** → campos com `Update = Y` | `SET` do `atualizar.sql` (e colunas do `existe.sql`) |
| Entradas **SQL** do job antes/depois da transformação | `antes.sql` / `depois.sql` |

Exemplo real, a Seção (`T-Secao_inicial.ktr` → `01_secao/`):

- **Table input** `SELECT seccod, secdes FROM secao WHERE seccod != '00'` → `origem.sql`.
- **String operations** (TRIM nos dois, UPPER na descrição), **Select values** (SECCOD
  Integer), **If null** (SECDES = 'RENOMEAR'), **Add constants**
  (`sec_situacao_sped = 'OUTROS'`) → `transformar.py`.
- **Sequence** `sq_secao` → `nextval('sq_secao')` no `inserir.sql`.
- **Insert/Update**: chave `SECCOD`, `SECDES` e `sec_situacao_sped` com Update = Y →
  `existe.sql` (`WHERE seccod = …`, devolvendo `secdes` e `sec_situacao_sped`) e
  `atualizar.sql` (`SET secdes = …, sec_situacao_sped = …`).

Dica: não adivinhe nomes de tabela ou coluna. Se o Pentaho ou os scripts SQL do time
não confirmam um nome, confirme no banco (`\d nome_da_tabela` no psql) antes de usar.

## 5. Um checkbox com várias tabelas (etapas)

Quando uma transformação do Pentaho grava várias tabelas que fazem sentido juntas
(como `T-TabelasBasicas_inicial`), crie **uma pasta de item com subpastas**, uma por
tabela. O item vira um checkbox só e as subpastas rodam em ordem:

```
comandos/04_tabelas_basicas/
├── modulo.json          ← nome do checkbox e grupo (sem origem.sql aqui)
├── 01_aplicacao/        ← cada subpasta tem os seus arquivos normais
│   ├── modulo.json      ← { "nome": "Aplicação", "chave": ["aplcod"] }
│   ├── origem.sql
│   ├── transformar.py
│   ├── existe.sql
│   ├── inserir.sql
│   └── atualizar.sql
├── 02_caracteristica/
└── ...
```

O motor decide sozinho: se a pasta do item tem `origem.sql`, é um item simples; se não
tem e tem subpastas, cada subpasta é uma etapa. No progresso cada etapa aparece numa
linha (`Tabelas Básicas › Marca`) com o seu relatório "linha a linha".

Para acrescentar uma tabela nova às Tabelas Básicas, basta criar mais uma subpasta
(ex.: `11_nova_tabela/`) e clicar em Recarregar.

**Só inserir, nunca atualizar** (como o Ramo, que no Pentaho está com "Don't perform any
updates"): faça o `existe.sql` e não crie o `atualizar.sql`. O que já existe fica como
"sem_alteracao".

**Comandos de apoio** (como o SQL "VF - Imposto Federal Geral" do job): use o
`depois.sql` do item. Ele aceita vários comandos separados por `;`, desde que não usem
`%(campo)s` (rodam uma vez só, não por linha).

## 6. Opções ao lado do checkbox (ex.: "Incluir produtos fora de linha")

Declare no `modulo.json` do item:

```json
"opcoes": [
  {"id": "fora_de_linha", "rotulo": "Incluir produtos fora de linha", "padrao": true,
   "dica": "texto que aparece ao passar o mouse"}
]
```

Na tela aparece um checkbox ao lado do item. Use o valor nos comandos:

- no `origem.sql` (Firebird): `:opcao_fora_de_linha` vale 1 (marcado) ou 0 (desmarcado), ex.:
  `AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)`
- nos `.sql` do PostgreSQL: `%(opcao_fora_de_linha)s` (verdadeiro/falso).

A opção vale para a execução inteira: outros itens (NCM, Preço, EAN...) podem usar a mesma
`:opcao_fora_de_linha` mesmo sem declará-la. O `padrao` vale quando a tela não manda nada.

## 7. Contagem na origem ("Na origem" e "Não migrados")

Antes de cada etapa o motor conta os registros da tabela de origem e a tela mostra **Na origem**
e **Não migrados** (= na origem − inseridos − atualizados − sem alteração). A tabela é a
primeira do `FROM` do `origem.sql`. Para trocar, use no `modulo.json`:

- `"tabela_origem": "NOME_DA_TABELA"`, ou
- `"contagem_origem": "SELECT COUNT(*) FROM ..."` (ex.: o NCM conta os NCMs distintos dos produtos;
  no Firebird, subconsulta no FROM precisa de apelido: `FROM (SELECT ...) t`).

A contagem é da tabela inteira, sem os filtros do `origem.sql` — por isso "Não migrados" mostra
também o que foi filtrado de propósito (ex.: a seção '00'). O relatório "linha a linha" mostra
o que deu erro ou foi pulado.

## 8. Quando um item depende de outro

Use o `validar.sql` para conferir que o "pai" já existe no VarejoFacil. Exemplo do
Grupo, que depende da Seção:

```sql
SELECT 1 FROM secao WHERE seccod = %(seccod)s
```

Se não encontrar, a linha vira erro com a mensagem do `mensagem_validacao` do
`modulo.json`. Os itens rodam na ordem das pastas: o Grupo enxerga as Seções gravadas
antes dele, então dá para migrar tudo de uma vez.

## 9. Problemas comuns

| Sintoma na tela | Causa provável |
|---|---|
| `falta inserir.sql` (checkbox desabilitado) | Arquivo obrigatório ausente ou com outro nome |
| `Column unknown` no item | Coluna errada no `origem.sql` (Firebird) |
| `campo 'nome' nao existe na linha` | O `transformar.py` usa `linha["nome"]`, mas o `origem.sql` não traz essa coluna |
| `inconsistent types deduced for parameter` | o mesmo `%(campo)s` aparece duas vezes em contextos de tipos diferentes: declare o tipo, ex.: `%(trbid)s::varchar` |
| `query parameter missing: nome` | Um `.sql` do PostgreSQL usa `%(nome)s`, mas o `transformar.py` não devolve esse campo |
| `column "x" does not exist` nas linhas | Nome errado no `inserir.sql`/`existe.sql` (PostgreSQL) |
| `null value in column "x" violates not-null constraint` | O destino exige a coluna `x`: inclua no `inserir.sql` |
| Todas as linhas "inserido" de novo a cada execução | Falta o `existe.sql` (sem ele, sempre insere) |
| Acentos trocados | Charset da conexão Firebird diferente do banco: troque na tela |
