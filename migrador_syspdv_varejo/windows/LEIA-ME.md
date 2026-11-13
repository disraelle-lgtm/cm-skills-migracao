# Migrador SysPDV → VarejoFacil — Windows

Tudo o que você precisa no Windows está nesta pasta.

## 1. Baixar os programas (uma vez)

Baixe do **Drive interno** para a sua pasta **Downloads** os instaladores que ainda não estiverem
no computador:

| Programa | Arquivo (o nome precisa começar assim) |
|---|---|
| Firebird 2.5 | `Firebird-*.exe` |
| PostgreSQL 15 | `postgresql-15*.exe` |
| pgAdmin 4 | `pgadmin4-*.exe` |
| Python 64 bits | `python-3*amd64*.exe` (sem ele, o instalador baixa o Python 3.12 do python.org) |

## 2. Instalar

Dê duplo clique em **`windows\instalar.bat`** (pede permissão de administrador uma vez). Ele:

1. instala, **um por um, só o que ainda não estiver instalado**, achando os arquivos na pasta
   Downloads (o que já existe é ignorado; o que não tiver instalador é avisado e pulado):

   | Programa | Como instala |
   |---|---|
   | Firebird 2.5 | silencioso, SuperServer como serviço (SYSDBA / masterkey) |
   | PostgreSQL 15 | silencioso, porta 5432, usuário `postgres` com a senha `SENHA_POSTGRES` do `instalar.bat` (padrão `postgres`) |
   | pgAdmin 4 | silencioso, para todos os usuários |
   | Python 64 bits | silencioso, para todos os usuários, no PATH |

2. copia o migrador para **`C:\migrador_syspdv_varejo`** (sem a pasta `linux`);
3. instala as dependências do migrador;
4. confere o client do Firebird (ver abaixo);
5. cria o atalho **"Migrador SysPDV"** na Área de Trabalho.

Para mudar a pasta de destino ou a senha do PostgreSQL, edite as linhas `DESTINO` e
`SENHA_POSTGRES` no começo do `instalar.bat`. Logs de cada programa: `%TEMP%\migrador_instaladores`.

## 3. Abrir

Atalho **"Migrador SysPDV"** na Área de Trabalho (ou `windows\iniciar-app.bat`). Abre uma janela
"Servidor do Migrador SysPDV" (deixe aberta) e o navegador em http://127.0.0.1:8020.
Para parar: feche essa janela ou `windows\parar-app.bat`.

## 4. Na tela

- A tela mostra só a aba **Windows** em Conexões (o sistema é detectado sozinho).
- **Procurar...** ao lado do caminho do banco: navega pelas unidades e pastas e mostra só os
  bancos `.fdb`/`.gdb`.
- Deixe o campo **fbclient** vazio.

### Origem SQL Server (em vez de Firebird)

Em **Banco de origem**, escolha **SQL Server** e preencha host, porta (1433) ou instância
(ex.: `SQLEXPRESS`), banco, usuário e senha. O SQL Server é aberto só para leitura.
O Windows já traz o driver ODBC "SQL Server", que funciona; para SQL Server mais novo, instale o
**ODBC Driver 18 for SQL Server** da Microsoft (o migrador escolhe sozinho o melhor instalado).
No SQL Server Configuration Manager, o protocolo **TCP/IP** precisa estar habilitado.

### Por que o client do Firebird de 64 bits

O migrador é 64 bits (o driver do PostgreSQL só existe em 64 bits no Windows) e o Firebird 2.5 do
SysPDV costuma ser 32 bits — um programa 64 bits não carrega o `fbclient.dll` de 32 bits
(`WinError 193`). Por isso esta pasta traz em `firebird_client_x64\` o **client 64 bits oficial**
do Firebird 2.5.9, que conversa normalmente com o servidor 32 bits. O Firebird instalado não é
alterado.

## 5. Atualizar para uma versão nova

Extraia o zip novo em qualquer pasta e rode **`windows\instalar.bat`** de novo: programas já
instalados são ignorados, o migrador é atualizado em `C:\migrador_syspdv_varejo`, os scripts
de versões antigas são removidos e o atalho é refeito. As pastas de comandos que você criou
são mantidas.
