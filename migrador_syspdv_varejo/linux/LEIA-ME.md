# Migrador SysPDV → VarejoFacil — Linux (Ubuntu)

Tudo o que você precisa no Linux está nesta pasta. Os comandos são rodados **a partir da pasta
do migrador** (`migrador_syspdv_varejo`).

## 1. Instalar (uma vez)

```bash
cd ~/migrador_syspdv_varejo
bash linux/instalar.sh
```

Ele instala o que faltar no sistema (`python3-venv`, `libfbclient2`, `curl` — pede a senha do
sudo), cria a `.venv` e instala as dependências do migrador.

O client do Firebird instalado é o 3.0 do Ubuntu (`libfbclient2`): ele conecta normalmente num
servidor Firebird 2.5, inclusive em Docker.

## 2. Abrir

```bash
cd ~/migrador_syspdv_varejo
bash linux/iniciar-app.sh
```

O navegador abre em http://127.0.0.1:8020. Se já houver um migrador rodando, ele é reiniciado
na versão desta pasta. Para parar: `kill $(cat .migrador.pid)`.

## 3. Na tela

- A tela mostra só a aba **Linux** em Conexões (o sistema é detectado sozinho).
- **Firebird em Docker:** o host é `localhost`, a porta é a publicada pelo container (ex.: 3051)
  e o caminho do .FDB é o de **dentro do container** (ex.: `/firebird/data/cliente/origem/syspdv_srv.fdb`).
- Deixe o campo **fbclient** vazio.
- No Linux, o arquivo .FDB precisa de permissão para o usuário do Firebird: `chmod 666 arquivo.fdb`.

## 3b. Origem SQL Server (em vez de Firebird)

Na tela, em **Banco de origem**, escolha **SQL Server** e preencha host, porta (1433) ou
instância, banco, usuário e senha. O SQL Server é aberto só para leitura.

O Linux precisa do driver ODBC da Microsoft (uma vez):

```bash
curl -sSL -O https://packages.microsoft.com/config/ubuntu/$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18
```

O `unixodbc` o `instalar.sh` já instala. Sem o driver, o teste de conexão avisa.

## 4. Atualizar para uma versão nova

```bash
cd ~ && unzip -o ~/Downloads/migrador_syspdv_varejo.zip -d ~
cd ~/migrador_syspdv_varejo && bash linux/iniciar-app.sh
```

Pastas que mudaram de nome em versões novas precisam ser apagadas (senão rodam duas vezes):
`rm -rf comandos/11_ajustes_pessoas comandos/29_ajustes_produto comandos/40_saldo_estoque comandos/41_movimentacao_custo`.

Se a sua pasta for de uma versão antiga (com `instalar.sh`/`iniciar-app.sh` na raiz), apague os
scripts antigos da raiz: `rm -f instalar.sh iniciar-app.sh *.bat instalar-windows.ps1` e
`rm -rf instalador_linux instalador_windows firebird_client_x64 instaladores`.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| `libncurses.so.5` | `sudo apt install libfbclient2` e deixe o fbclient vazio |
| "porta 8020 ocupada por outro programa" | `fuser -k 8020/tcp` e abra de novo |
| Erro de I/O ao abrir o .FDB | caminho errado (no Docker, use o de dentro do container) ou falta `chmod 666` |
