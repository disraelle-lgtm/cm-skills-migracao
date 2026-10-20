# Instalação DB2 11.1 no Linux Ubuntu — Passo a passo completo

## Ambiente utilizado

* Ubuntu Linux
* DB2 11.1.4.7
* Usuário da instância: `admin`
* Instalação funcional com DBeaver

---

# 1. Atualizar sistema

```bash id="pjlwmv"
sudo apt update
sudo apt upgrade -y
```

---

# 2. Instalar dependências

```bash id="q6rtkj"
sudo apt install -y \
libaio1 \
ksh \
binutils \
libpam0g \
rpm \
alien \
libstdc++6 \
numactl \
gcc \
g++ \
make
```

---

# 3. Criar usuário da instância

```bash id="z9l3we"
sudo useradd -m admin
sudo passwd admin
```

Definir senha.

---

# 4. Baixar DB2 11.1

Extrair o instalador:

```bash id="sxv58m"
tar -xvf v11.1_linuxx64_server_t.tar.gz
```

Entrar na pasta:

```bash id="8lm4co"
cd server_t
```

---

# 5. Executar pré-verificação

```bash id="o0zqny"
./db2prereqcheck
```

Corrigir dependências caso apareçam erros.

---

# 6. Instalar DB2

```bash id="w4bfv2"
sudo ./db2setup
```

Abrirá interface gráfica/texto.

---

# 7. Durante instalação

Selecionar:

* DB2 Server Edition
* instalação típica

---

# 8. Criar instância

Na etapa da instância:

## usuário da instância

```text id="jlwmsh"
admin
```

## senha

definir senha desejada.

---

# 9. Finalizar instalação

Após conclusão:

```bash id="o6nzhx"
sudo /opt/ibm/db2/V11.1/bin/db2ls
```

---

# 10. Entrar no usuário da instância

```bash id="kqzjlwm"
su - admin
```

---

# 11. Carregar ambiente DB2

```bash id="m4nzx8"
source ~/sqllib/db2profile
```

---

# 12. Iniciar DB2

```bash id="c1vy0a"
db2start
```

Resultado esperado:

```text id="dd6r4v"
SQL1063N DB2START processing was successful.
```

---

# 13. Verificar versão

```bash id="fsk7r2"
db2level
```

Resultado esperado:

```text id="w9h1px"
DB2 v11.1.4.7
```

---

# 14. Configurar SYSADM_GROUP corretamente

Verificar:

```bash id="q2xjcv"
db2 get dbm cfg | grep SYSADM
```

Configurar:

```bash id="ewm4rk"
db2 update dbm cfg using SYSADM_GROUP admin
```

Reiniciar DB2:

```bash id="yk1a8d"
db2stop force
db2start
```

---

# 15. Liberar acesso TCP/IP

Editar serviços:

```bash id="c9qjlwm"
sudo nano /etc/services
```

Adicionar:

```text id="h74n3y"
db2c_admin 50000/tcp
```

---

# 16. Configurar porta DB2

Como usuário `admin`:

```bash id="y3z7ks"
db2 update dbm cfg using SVCENAME db2c_admin
```

Reiniciar:

```bash id="s6bx1v"
db2stop force
db2start
```

---

# 17. Liberar firewall

Ubuntu:

```bash id="y2e6jm"
sudo ufw allow 50000/tcp
```

---

# 18. Testar listener

```bash id="m1rkx5"
netstat -plnt | grep 50000
```

ou:

```bash id="t8n5qa"
ss -plnt | grep 50000
```

Resultado esperado:

```text id="h1xq7m"
0.0.0.0:50000
```

---

# 19. Criar banco teste

```bash id="r5jlwm"
db2 create db testdb
```

Conectar:

```bash id="q8t2fy"
db2 connect to testdb
```

---

# 20. Instalar driver no DBeaver

No DBeaver:

* Nova conexão
* IBM DB2

Parâmetros:

* Host: IP do servidor
* Porta: 50000
* Database: testdb
* User: admin
* Password: senha

---

# 21. Testar conexão externa

```sql id="zt7u8r"
select current date from sysibm.sysdummy1;
```

---

# 22. Configurar inicialização automática

Linux:

```bash id="k3n5xd"
sudo systemctl enable db2fmcd
```

---

# 23. Comandos úteis

## iniciar DB2

```bash id="0jlwmn"
db2start
```

## parar DB2

```bash id="s5y2wj"
db2stop force
```

## listar bancos

```bash id="w8c1rv"
db2 list db directory
```

## listar instâncias

```bash id="m4k2xz"
db2ilist
```

## verificar configuração

```bash id="z1u9tq"
db2 get dbm cfg
```

## verificar processos

```bash id="r6qjlwm"
ps -ef | grep db2
```

---

# Observações importantes

## DB2 11.1 no Ubuntu moderno

Às vezes exige:

```bash id="y7r4ms"
sudo ln -s /lib/x86_64-linux-gnu/libpam.so.0 /lib64/libpam.so
```

---

## Problema comum — source não funciona

No shell `sh`:

Use:

```bash id="q9e1wx"
. ~/sqllib/db2profile
```

e não:

```bash id="s4jlwm"
source
```

---

## Problema comum — permissões

Sempre usar:

```bash id="k2n7cv"
chmod -R 777
```

temporariamente durante restore/testes.

---

# Estrutura recomendada

## dados

```text id="e5y4ra"
/home/admin/dbdata
```

## backups

```text id="n8m2qt"
/home/admin/backup
```

## logs restore

```text id="x3v7pk"
/home/admin/logs_cisserp
```
