# Restaurar backup DB2 no Linux (DB2 11.1)

Passo a passo completo — Restaurar backup DB2 no Linux (DB2 11.1)
Ambiente utilizado
Linux Ubuntu
DB2 11.1
Instância DB2: admin
Banco restaurado: CISSERP
1. Entrar no usuário da instância
su - admin

Carregar ambiente do DB2:

source ~/sqllib/db2profile

2. Iniciar DB2
db2start

3. Criar diretório para os dados do banco
mkdir -p /home/admin/dbdata/CISSERP
chmod -R 777 /home/admin/dbdata

4. Restaurar backup em modo REDIRECT

Ir para pasta do backup:

cd /home/[usuario]/bd-clientes/[CLIENTE]/origem/

Executar:

db2 restore db CISSERP \
from /home/[usuario]/bd-clientes/[CLIENTE]/origem/ \
taken at 20260422100902 \
into CISSERP \
redirect generate script restore.sql
5. Alterar caminhos do restore

Substituir caminhos antigos:

sed -i 's#/db2/DATABASES/CISSERP#/home/admin/dbdata/CISSERP#g' restore.sql
6. Criar estrutura de diretórios
mkdir -p \
/home/admin/dbdata/CISSERP/DBPARTITION0/TABLESPACES/DMS/DATA/{DATA001,DATA002,DATA003,DATA004}

mkdir -p \
/home/admin/dbdata/CISSERP/DBPARTITION0/TABLESPACES/DMS/INDEX/{INDEX001,INDEX002,INDEX003,INDEX004}

mkdir -p \
/home/admin/dbdata/CISSERP/DBPARTITION0/TABLESPACES/DMS/LONG/{LONG001,LONG002,LONG003,LONG004}

mkdir -p \
/home/admin/dbdata/CISSERP/DBPARTITION0/TABLESPACES/SMS/{SYSCAT,TEMPSPACE1,TBS_REORG,TEMPCISS04K,TEMPCISS32K,TBSUTCISS32K_001}

chmod -R 777 /home/admin/dbdata
7. Executar restore
db2 -tvf restore.sql
8. Restaurar logs (ROLLFORWARD)

Criar diretório:

mkdir -p /home/admin/logs_cisserp

Mover logs:

mv /home/[usuario]/bd-clientes/[CLIENTE]/origem/logs_restore/*.LOG /home/admin/logs_cisserp/

Permissões:

chmod -R 777 /home/admin/logs_cisserp

Executar rollforward:

db2 "rollforward db CISSERP to end of logs overflow log path ('/home/admin/logs_cisserp')"

Finalizar:

db2 "rollforward db CISSERP complete overflow log path ('/home/admin/logs_cisserp')"
9. Testar conexão
db2 connect to CISSERP
10. Corrigir SYSADM_GROUP

Verificar:

db2 get dbm cfg | grep SYSADM

Configurar corretamente:

db2 update dbm cfg using SYSADM_GROUP admin

Reiniciar DB2:

db2stop force
db2start
11. Conceder permissões ao usuário ADMIN

Criar usuário Linux:

sudo useradd -m db2inst1
sudo passwd db2inst1

Entrar no usuário:

su - db2inst1

Carregar profile:

. ~admin/sqllib/db2profile

Conectar:

db2 connect to CISSERP

Dar permissões:

db2 "grant dbadm on database to user ADMIN"
db2 "grant dataaccess on database to user ADMIN"
db2 "grant accessctrl on database to user ADMIN"
12. Configurar DBeaver

Parâmetros:

Host: IP do servidor
Porta: 50000
Banco: CISSERP
Usuário: ADMIN
Senha: senha do Linux
13. Testar SELECT
select * from ADM.PRODUTOS fetch first 10 rows only;
Observações importantes
Backup online

Esse backup foi ONLINE.

Por isso:

exigiu ROLLFORWARD
exigiu logs .LOG

Sem os logs:

o banco entra em ROLL-FORWARD PENDING
Quando vier atualização futura

Da próxima vez:

opção mais segura
apagar banco atual:
db2 drop db CISSERP
repetir todo processo.
Backup incremental

Se futuramente o cliente enviar:

backup incremental
delta
logs adicionais

o procedimento muda.

Comandos úteis
listar bancos
db2 list db directory
listar tabelas
db2 list tables for all
listar tablespaces
db2 list tablespaces show detail
backup do banco
db2 backup db CISSERP to /home/admin/backup
conectar
db2 connect to CISSERP
parar DB2
db2stop force
iniciar DB2
db2start