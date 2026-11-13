# MCP do Migrador — leitura livre, migração só com aprovação

Servidor MCP que mora **dentro** do migrador (`servidor_mcp\`). Ele dá ao Claude dois poderes bem diferentes:

| Modo | O que o Claude faz | Precisa de aprovação? |
| --- | --- | --- |
| **Leitura** | Consulta Firebird, SQL Server e PostgreSQL para conferir dados, comparar origem × destino, investigar chamados | **Não** (somente leitura) |
| **Migração** | Pede para rodar uma etapa do migrador (simulação, migração real, ajuste de códigos) | **Sim, a cada pedido** |

Nenhum arquivo do app foi alterado. O MCP chama a **mesma API** que a tela do migrador usa (`/modulos`, `/migrar`,
`/status`, `/codigos/*`), então as regras, a ordem das etapas e os itens automáticos continuam sendo os do app.

## Como funciona a aprovação

```
Claude: solicitar_execucao(...)        → cria o PEDIDO  A3F09C   (nada é executado)
Você:   aprovar.bat A3F09C             → lê o resumo e digita a frase de confirmação
Claude: executar_pedido_aprovado(...)  → executa UMA vez
Claude: status_execucao(...)           → acompanha; confere com consultas de leitura
```

- **Quem aprova é você, num terminal.** O script `aprovar_migracao.py` só funciona em terminal interativo e exige
  digitar uma frase: `SIMULAR` para simulação, ou **o nome do banco de destino** para migração real e ajuste de códigos.
  Nenhuma ferramenta do MCP aprova ou recusa pedidos.
- **Uma aprovação = uma execução.** Depois de usada, vencida (15 min, configurável) ou recusada, não vale mais.
- **Uma etapa por pedido** (`max_itens_por_aprovacao: 1`). O Claude pede etapa por etapa, na ordem das pastas, e deve
  parar no primeiro erro.
- **A aprovação fica presa ao que você viu.** O pedido guarda os parâmetros e um hash do **conteúdo dos SQL/Python** que
  vão rodar (inclusive dos itens automáticos) e do arquivo de códigos da virada. Se algo mudar entre a aprovação e a
  execução, o pedido cai (`invalidada`) e é preciso pedir de novo.
- **Senhas nunca vão para o pedido.** Ficam em variáveis de ambiente e só viajam, pelo próprio computador, na chamada ao migrador.

### Dois avisos que aparecem na tela de aprovação (e por quê)

1. **A simulação não é totalmente inofensiva.** Ela roda e desfaz as gravações no fim, **mas** o `finalizar.sql` de cada
   etapa é confirmado (commit) mesmo na simulação, e contadores (*sequences*) do PostgreSQL não voltam atrás. Por isso
   a simulação também pede aprovação.
2. **Itens automáticos entram junto.** O `99_fila_panama` roda no fim de **toda** migração e **apaga e recria**
   `fila_sincronizacao` e `fila_sincronizacao_panama`. A tela de aprovação lista esses itens e a descrição de cada um.

Na migração **real**, cada etapa é confirmada ao terminar: o que já concluiu **não** é desfeito se uma etapa seguinte
falhar. Faça backup do banco de destino antes e ensaie num banco de homologação.

## Instalação (Windows)

1. Tenha o migrador instalado (`windows\instalar.bat`), normalmente em `C:\migrador_syspdv_varejo`.
2. Rode `servidor_mcp\instalar-mcp.bat`. Ele instala o pacote `mcp` no mesmo `.venv` do migrador e cria o `conexoes.json`.
3. Edite `conexoes.json` (modelo em `conexoes.exemplo.json`) e defina as senhas como variáveis de ambiente **do usuário**:

```bat
setx MCP_FB_ORIGEM_SENHA   "senha-do-usuario-de-leitura"
setx MCP_PG_LEITURA_SENHA  "senha-do-usuario-de-leitura"
setx MCP_PG_DESTINO_SENHA  "senha-do-usuario-de-migracao"
```

4. Para o SQL Server, instale o *Microsoft ODBC Driver 17 ou 18 for SQL Server*. O Firebird usa o `fbclient.dll` que já vem em
   `windows\firebird_client_x64\` (informe em `fbclient`).
5. Feche e abra o Claude (e o terminal) para ele enxergar as variáveis.

### Conexões: `uso` separa leitura de migração

Cada conexão tem `"uso": "leitura"` (padrão) ou `"migracao"`:

- **leitura** serve para consultas. Crie usuários **somente leitura** (veja abaixo). O validador de SQL ajuda, mas a
  proteção que não falha é a permissão do usuário no banco.
- **migracao** é o usuário com escrita no PostgreSQL de destino e **só é usado para migrar**. As ferramentas de consulta
  **recusam** conexões `migracao`, para que um usuário com escrita nunca seja usado para ler.
- O **destino** de uma migração tem de ser PostgreSQL com `uso: migracao`. A **origem** é Firebird ou SQL Server.

Usuário somente leitura (rodado por quem administra o banco):

```sql
-- PostgreSQL (VarejoFacil)
CREATE ROLE leitura_mcp LOGIN PASSWORD '<SENHA_FORTE>';
GRANT CONNECT ON DATABASE varejofacil TO leitura_mcp;
GRANT USAGE ON SCHEMA public TO leitura_mcp;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO leitura_mcp;
```

Firebird 2.5: crie o usuário (`gsec -user SYSDBA -password <SENHA_ADMIN> -add LEITURA_MCP -pw <SENHA_FORTE>`) e, no isql,
conectado como SYSDBA/dono (não dê `EXECUTE` em procedures):

```sql
SET TERM ^ ;
EXECUTE BLOCK AS DECLARE VARIABLE T VARCHAR(63);
BEGIN
  FOR SELECT TRIM(RDB$RELATION_NAME) FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG,0) = 0 INTO :T
  DO EXECUTE STATEMENT 'GRANT SELECT ON "' || T || '" TO LEITURA_MCP';
END^
SET TERM ; ^
COMMIT;
```

SQL Server:

```sql
CREATE LOGIN leitura_mcp WITH PASSWORD = '<SENHA_FORTE>';
USE ERP;
CREATE USER leitura_mcp FOR LOGIN leitura_mcp;
ALTER ROLE db_datareader ADD MEMBER leitura_mcp;
DENY EXECUTE TO leitura_mcp;
```

## Registrar no Claude

O servidor usa **stdio** (roda na sua máquina): funciona no **Claude Desktop** e no **Claude Code**, não no Claude.ai pelo navegador.

**Claude Desktop** — `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "migrador-cm": {
      "command": "C:\\migrador_syspdv_varejo\\.venv\\Scripts\\python.exe",
      "args": ["C:\\migrador_syspdv_varejo\\servidor_mcp\\server.py"]
    }
  }
}
```

**Claude Code:**

```powershell
claude mcp add migrador-cm -- C:\migrador_syspdv_varejo\.venv\Scripts\python.exe C:\migrador_syspdv_varejo\servidor_mcp\server.py
```

**Não marque "sempre permitir" em `executar_pedido_aprovado`.** Deixe o Claude pedir sua permissão também no cliente: é uma
segunda confirmação, além da aprovação no terminal.

## Passo a passo de uma etapa

1. Abra o migrador (`windows\iniciar-app.bat`). O MCP precisa dele aberto (`status_migrador` confere).
2. No Claude: *"Simule a etapa 01_secao da origem_firebird para o vf_destino."*
3. O Claude cria o pedido e informa o código. Abra um terminal e rode `servidor_mcp\aprovar.bat CODIGO`, leia o resumo
   (origem, destino, itens, itens automáticos, avisos) e digite a frase pedida.
4. Avise o Claude. Ele executa e acompanha com `status_execucao`; peça que confira o resultado com consultas de leitura.
5. Repita com `simular: false` para gravar de verdade (novo pedido, nova aprovação, frase = nome do banco).

Para recusar: `aprovar.bat CODIGO --recusar`. Para ver os pendentes: `aprovar.bat` sem código.

## Ferramentas

| Ferramenta | Tipo |
| --- | --- |
| `listar_conexoes`, `testar_conexao`, `listar_tabelas`, `descrever_tabela`, `amostra_tabela`, `executar_consulta` | Leitura (3 bancos) |
| `status_migrador`, `listar_itens_migracao`, `consultar_codigos`, `status_pedido`, `status_execucao`, `status_ajuste_codigos` | Leitura |
| `solicitar_execucao`, `solicitar_ajuste_codigos` | Só criam o pedido (nada executa) |
| `executar_pedido_aprovado` | Executa um pedido **já aprovado por você** (destrutiva; uma vez) |

Estados do pedido: `pendente` → `aprovada` → `executando` → `usada`; ou `recusada`, `expirada`, `invalidada`
(algo mudou depois da aprovação) e `indeterminada` (o migrador não respondeu e não dá para saber se começou: **nunca é
repetido automaticamente**; confira a tela do migrador antes de agir).

## O que a proteção NÃO cobre (seja direto)

- **A API do migrador (porta 8020) não tem login.** Qualquer programa local pode chamar `/migrar`. Isso já era assim; o
  MCP não muda isso, ele só garante que o *Claude* passe pela sua aprovação.
- **Claude Code com acesso a arquivos.** A aprovação é um arquivo em `servidor_mcp\aprovacoes\`. No Claude Desktop o
  Claude não tem como mexer nele. No Claude Code, um agente com permissão de editar arquivos poderia, em tese, forjar
  um pedido; negue a edição dessa pasta nas permissões do Claude Code, ou faça as migrações pelo Claude Desktop.
- **Validador de SQL (leitura)** não pega procedures selecionáveis do Firebird nem funções com efeito colateral: use
  sempre usuário só de leitura.
- **Dados de clientes passam pelo Claude.** Prefira homologação e confirme que o uso está coberto pelo contrato e pela LGPD.
  Colunas como `SENHA`/`TOKEN` voltam como `***` (`mascarar_colunas`).
- Tudo é registrado em `auditoria.log` (só SQL e pedidos, nunca resultados).

## Configurações úteis (`conexoes.json`)

| Chave | Padrão | Efeito |
| --- | --- | --- |
| `max_itens_por_aprovacao` | 1 | Quantos itens um pedido pode cobrir (1 = uma etapa por aprovação) |
| `aprovacao_validade_minutos` | 15 | Prazo para aprovar e executar |
| `app_url` | `http://127.0.0.1:8020` | Só aceita endereço do próprio computador |
| `limite_linhas_maximo` | 1000 | Teto de linhas por consulta |

## Testes

```bat
..\.venv\Scripts\pip install pytest
..\.venv\Scripts\python -m pytest tests
```

106 testes: validador de SQL, aprovação (frase, terminal interativo, uso único, vencimento, adulteração de parâmetros e de
SQL, execução simultânea), execução contra um migrador de teste e protocolo MCP. Também foi executado contra o app real
do migrador (itens, automáticos, recusa de conexão) sem tocar em nenhum banco.

**Não foram testados com bancos reais:** conexões Firebird/SQL Server/PostgreSQL pelo MCP, as consultas de metadados
(`RDB$*`, `INFORMATION_SCHEMA`) e uma migração completa. Na primeira vez, rode `testar_conexao`/`descrever_tabela` e faça
uma **simulação** num banco de homologação antes de qualquer migração real.

## Problemas comuns

| Sintoma | Causa provável |
| --- | --- |
| "O migrador não está aberto" | Abra `windows\iniciar-app.bat` |
| "O usuário ainda NÃO aprovou" | Rode `aprovar.bat CODIGO` e digite a frase |
| "Aprovar só funciona num terminal interativo" | Abra um terminal de verdade (não o do Claude) |
| "O pedido expirou" | Peça de novo (vale 15 min) |
| "Os itens ou os SQLs mudaram depois da aprovação" | Alguém editou `comandos\`; peça de novo e releia o resumo |
| "variável de ambiente ... não está definida" | Rode o `setx` e reinicie o Claude |
| `WinError 193` | `fbclient.dll` de arquitetura diferente da do Python |
