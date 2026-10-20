#!/bin/bash

HORA=`date +%k`
if [ $HORA -ge 6 ] && [ $HORA -lt 12 ];then
TURNO="Bom Dia!"; fi;
if [ $HORA -ge 12 ] && [ $HORA -lt 18 ];then
TURNO="Boa Tarde!"; fi;
if [ $HORA -ge 18 ] && [ $HORA -lt 24 ];then
TURNO="Boa Noite!"; fi;
if [ $HORA -ge 0 ] && [ $HORA -lt 6 ];then
TURNO="Boa Noite!"; fi;

Menu () {
    echo -e "\033[01;32m#-----------------------------------------------------#"
    echo -e "|                                                     |"
    echo -e "| \033[01;33m$TURNO $USER hoje é `date +%x`, `date +%A` às `date +%H:%M`\033[01;32m |"
    echo -e "|                                                     |"
    echo -e "|                 \033[01;33mO que deseja fazer?\033[01;32m                 |"
    echo -e "|                                                     |"
    echo -e "|  \033[01;37m00 \033[01;32m- \033[01;36mSair                                          \033[01;32m|"
    echo -e "|  \033[01;37m01 \033[01;32m- \033[01;36mConectar ao Stage                             \033[01;32m|"
    echo -e "|  \033[01;37m02 \033[01;32m- \033[01;36mAbrir o Pentaho                               \033[01;32m|"
    echo -e "|  \033[01;37m03 \033[01;32m- \033[01;36mEditar o arquivo configuracoes.properties     \033[01;32m|"
    echo -e "|  \033[01;37m04 \033[01;32m- \033[01;36mOperações Postgres                            \033[01;32m|"
    echo -e "|  \033[01;37m05 \033[01;32m- \033[01;36mOperações Firebird                            \033[01;32m|"
    echo -e "|  \033[01;37m06 \033[01;32m- \033[01;36mOperações Varejo Facil                        \033[01;32m|"
    echo -e "|  \033[01;37m07 \033[01;32m- \033[01;36mAtualiza Credenciais AWS                      \033[01;32m|"
    echo -e "|  \033[01;37m99 \033[01;32m- \033[01;36mAbre Jupter Notebook                          \033[01;32m|"
    echo -e "|                                                     |"
    echo -e "#-----------------------------------------------------#\033[01;37m"
    echo 
    read -re OPCAO
    case $OPCAO in
        0) Adeus ;; 
        1) ConectaStage ;; 
        2) AbrePentaho ;; 
        3) EditaProperties ;; 
        4) OperacaoPostgres ;; 
        5) OperacaoFirebird ;; 
        6) VarejoFacil ;; 
        7) AtualizaCredenciaisAWS ;; 
       99) AbreJupterNotebook ;; 
        *) echo -e "Opção Inválida!" && Menu ;;
    esac
}

Adeus () {
        echo 
        echo -e "\033[01;33mTenha um(a) $TURNO $USER!"
        echo
        exit
}

ConectaStage () {
    echo
    echo -e "\033[01;32m#----------------------------------------------------#"
    echo -e "|						     |"
    echo -e "| \033[01;33mEm qual Stage deseja conectar?                     \033[01;32m|"
    echo -e "|						     |"
    echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Principal                    \033[01;32m|"
    echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mStage Antigo Versão Postgres 10               \033[01;32m|"
    echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mStage Novo Versão Postgres 12                 \033[01;32m|"
    echo -e "|						     |"
    echo -e "#----------------------------------------------------#\033[01;37m"
    echo
    read -re OPCAO
    echo
    case $OPCAO in
        0) Menu ;;
        1) aws ssm start-session --target i-0e6a8e42aac0de227 --profile cmadmin  ;;
        2) aws ssm start-session --target i-056f9ff343b3ac186 --profile vfprod ;;
        *) echo -e "Função Inválida!!!" && ConectaStage;    
    esac
        echo -e
        Menu
        echo

}

AbrePentaho () {
    echo 
    echo -e "\033[01;32m#----------------------------------------------------#"
    echo -e "|						     |"
    echo -e "| \033[01;33mDeseja alterar o arquivo kettle.properties?        \033[01;32m|"
    echo -e "|						     |"
    echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Principal                    \033[01;32m|"
    echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mSim quero editar arquivo kettle.properties e  \033[01;32m|"
    echo -e "|      \033[01;36mabrir o Pentaho                               \033[01;32m|"
    echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mNão quero abrir logo o Pentaho                \033[01;32m|"
    echo -e "|						     |"
    echo -e "#----------------------------------------------------#\033[01;37m"
    echo -e 
    read -re RESPOSTA
    case $RESPOSTA in
    0) echo && Menu ;; 
    1) echo
       vi ~/.kettle/kettle.properties
       cd ~/data-integration
       source /etc/environment
       ./spoon.sh
       echo
       Menu ;;
    2) echo
       cd ~/data-integration/
       source /etc/environment
       ./spoon.sh
       echo
	   Menu ;;
    *) echo -e "Opção Inválida!" && AbrePentaho ;;
    esac  
}

EditaProperties () {
    echo
    docker stop varejofacil
    sudo vi /home/$USER/workspace/varejofacil/configuracoes.properties
    docker start varejofacil
    docker exec varejofacil /opt/apache-activemq-5.15.6/bin/activemq start
    echo
    Menu
}

OperacaoPostgres () {
    echo
    echo -e "\033[01;32m#----------------------------------------------------#"
    echo -e "|	                                             |"
    echo -e "|             \033[01;33mO que deseja fazer?                    \033[01;32m|"
    echo -e "|						     |"
    echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Principal                    \033[01;32m|"
    echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mCriar Banco de dados!                         \033[01;32m|"
    echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mRealizar Backup dos banco!                    \033[01;32m|"
    echo -e "| \033[01;37m03 \033[01;32m- \033[01;36mExcluir o Banco de Dados		             \033[01;32m|"
    echo -e "|	                                             |"
    echo -e "#----------------------------------------------------#\033[01;37m"
    echo 
    read -re OPERACAO_BANCO 
    case $OPERACAO_BANCO in
    0) echo && Menu ;;
    1)
        echo
        echo -e "\033[01;32m#----------------------------------------------------#"
        echo -e "|                                                    |"
        echo -e "|             \033[01;33mQual a versão do Postgres?             \033[01;32m|"
        echo -e "|                                                    |"
        echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Anterior                     \033[01;32m|"
        echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mPostgres Versão 10.0                          \033[01;32m|"
        echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mPostgres Versão 12.0                          \033[01;32m|"
        echo -e "|                                                    |"
        echo -e "#----------------------------------------------------#\033[01;37m"
        echo
        read -re V1
        echo 
        read -ep 'Informe o nome do banco: ' banco
        read -ep 'Informe o caminho do arquivo: ' arquivo
        case $V1 in
        0) OperacaoPostgres ;;
        1) echo 
           echo 'Deletando banco caso exista...'
           psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
           echo 'Restaurando banco...'
           psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='pt_BR.UTF-8' CONNECTION LIMIT=-1;"
           pg_restore -h localhost -p 5432 -U postgres -O -v -d $banco $arquivo$banco.backup 
           Menu ;;
        2) echo 
           echo 'Deletando banco caso exista...'
        #    psql -h 172.17.0.1 -p 5432 -U postgres -W 123 -c "DROP DATABASE IF EXISTS $banco;"
           PGPASSWORD="postgres" psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
           echo 'Restaurando banco...'
           # psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='pt_BR.UTF-8' CONNECTION LIMIT=-1;"
        #    psql -h 172.17.0.1 -p 5432 -U postgres -W 123 -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' CONNECTION LIMIT=-1;" &&
        #    pg_restore12 -v -h 172.17.0.1 -p 5432 -U postgres -W 123 -O -v -d $banco $arquivo$banco.backup 
           PGPASSWORD="postgres" psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' CONNECTION LIMIT=-1;" &&
           PGPASSWORD="postgres" pg_restore12 -v -h localhost -p 5432 -U postgres -O -v -d $banco $arquivo$banco.backup 
           Menu ;;
        *) echo -e 'Opção Inválida !!'
           OPERACAO_BANCO ;;
        esac ;;
    2)
        echo
        echo -e "\033[01;32m#----------------------------------------------------#"
        echo -e "|                                                    |"
        echo -e "|             \033[01;33mO que deseja fazer?                    \033[01;32m|"
        echo -e "|                                                    |"
        echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Anterior                     \033[01;32m|"
        echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mBackup Migração!                              \033[01;32m|"
        echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mBackup Debug!                                 \033[01;32m|"
        echo -e "| \033[01;37m03 \033[01;32m- \033[01;36mBackup Segurança!                             \033[01;32m|"
        echo -e "|                                                    |"
        echo -e "#----------------------------------------------------#\033[01;37m"
        echo 
        read -re OPCAO_BACKUP_POSTGRES
        case $OPCAO_BACKUP_POSTGRES in
          0) OperacaoPostgres ;;
          1) read -rep 'Informe o nome do banco para efetuar o backup: ' banco
             read -rep 'Informe o caminho do arquivo: ' arquivo
             read -ep 'Informe a versão do Postgresql (10 ou 12): ' versao
             echo -e
             migrado='_migrado'
             dia=`date +%d%m`
             echo 'Fazendo backup do banco...'
             if [ $versao -eq 10 ]; then   
                  PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco$migrado$dia.backup
             elif [ $versao -eq 12 ]; then
                  PGPASSWORD="postgres" pg_dump12 -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco$migrado$dia.backup
             fi
             echo 'Backup concluído com sucesso !!!'
             echo
             echo 'Atualizando Credenciais vfprod !!!'
             echo
                 aws sso login --profile vfprod
             echo '#############################################################################################'
             echo 
             echo 'Credencial vfprod atualizadas com sucesso!!'
             echo
             echo 'Enviando backup para o S3'
             echo '#############################################################################################'
             echo
                 cd $arquivo
                 aws s3 cp $banco$migrado$dia.backup s3://migracao-varejofacil-databases/ --profile vfprod
             echo
             echo '#############################################################################################'
             echo 'Envio de backup concluído !!!'
             echo '#############################################################################################'
             echo
             echo '#############################################################################################'
             echo
             echo -e "Colar no Stage:" 
             echo -e "aws s3 cp s3://migracao-varejofacil-databases/$banco$migrado$dia.backup ."
             echo
             echo '#############################################################################################'
             echo
             Menu ;;
          2) read -rep 'Informe o nome do banco para efetuar o backup: ' banco
             read -rep 'Informe o caminho do arquivo: ' arquivo
             read -ep 'Informe a versão do Postgresql (10 ou 12): ' versao
             debug='DEBUG'
             echo 'Fazendo backup do banco...'
             if [ $versao -eq 10 ]; then
                  PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco'_DEBUG'.backup
             elif [ $versao -eq 12 ]; then
                  PGPASSWORD="postgres" pg_dump12 -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco'_DEBUG'.backup
             fi
             echo
             echo 'Backup concluído com sucesso !!!'
             echo
             Menu ;;
          3) read -rep 'Informe o nome do banco para efetuar o backup: ' banco
             read -rep 'Informe o caminho do arquivo: ' arquivo
             read -ep 'Informe a versão do Postgresql (10 ou 12): ' versao
             echo 'Fazendo backup do banco...'
             if [ $versao -eq 10 ]; then
                  PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco.backup
             elif [ $versao -eq 12 ]; then
                  PGPASSWORD="postgres" pg_dump12 -h localhost -p 5432 -U postgres -O -v -Fc -d $banco -f $arquivo$banco.backup
             fi
             echo
             echo 'Backup concluído com sucesso !!!'
             echo
             Menu ;;
          *) echo -e 'Opção Inválida !!'
        esac
    ;;
    3)
        echo
        read -rep 'Informe o nome do banco para efetuar o backup: ' banco
        read -ep 'Informe a versão do Postgresql (10 ou 12): ' versao
        echo 'Dropando Banco ...'
        if [ $versao -eq 10 ]; then
             psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
        elif [ $versao -eq 12 ]; then
               psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
        fi
        echo
        echo -e "Realizada exclusão do banco $DROPA conforme solicitada"
        echo
        OperacaoPostgres
        echo
    ;;
    *) 
        echo
        echo -e "Opção Inválida!" && OperacaoPostgres 
        echo
    ;;
    esac
}

RestaurarBancoPostgres() {
    read -ep 'Informe o nome do banco: ' banco
    read -ep 'Informe o caminho do arquivo: ' arquivo
    read -ep 'Informe a versão do Postgresql (10 ou 12): ' versao
    if [ $versao -eq 10 ]; then
        echo 'Deletando banco caso exista...'
        psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
        echo 'Restaurando banco...'
        psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='pt_BR.UTF-8' CONNECTION LIMIT=-1;"
        pg_restore -h localhost -p 5432 -U postgres -O -v -d $banco $arquivo$banco.backup
    elif [ $versao -eq 12 ]; then
        echo 'Deletando banco caso exista...'
        psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
        echo 'Restaurando banco...'
        # psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='pt_BR.UTF-8' CONNECTION LIMIT=-1;"
        psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE unico WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' CONNECTION LIMIT=-1;" &&
        PGPASSWORD="123" pg_restore12 -v -h localhost -p 5432 -U postgres -O -v -d $banco $arquivo$banco.backup
    fi    
    echo
    echo 'Restore conluído com sucesso !!'
    Menu
}

OperacaoFirebird () {
	echo
	read -ep 'Informe o nome do banco: ' BANCO_FIREBIRD
    read -ep 'Informe o caminho do banco: ' CAMINHO_BANCO_FIREBIRD
    echo
    sudo mv $CAMINHO_BANCO_FIREBIRD/$BANCO_FIREBIRD.fdb /srv/firebird/$BANCO_FIREBIRD.fdb
    sudo chmod 777 /srv/firebird/$BANCO_FIREBIRD.fdb
    echo
    sudo gbak -b -v -user sysdba -password masterkey /srv/firebird/$BANCO_FIREBIRD.fdb /srv/firebird/$BANCO_FIREBIRD.fbk
    echo 
    echo -e "Primeira etapa concluída, gerado arquivo:"
    echo -e /srv/firebird/$BANCO_FIREBIRD.fbk
    echo
    sudo gbak -R -v -user sysdba -password masterkey /srv/firebird/$BANCO_FIREBIRD.fbk /srv/firebird/$BANCO_FIREBIRD.fdb
    echo  -e "Reparação realizada com sucesso!!"
    sudo mv /srv/firebird/$BANCO_FIREBIRD.fdb $CAMINHO_BANCO_FIREBIRD/$BANCO_FIREBIRD.fdb
    echo
    echo -e "Renomeado arquio antigo"
	Menu
}

VarejoFacil () {
	echo
	echo -e "\033[01;32m#----------------------------------------------------#"
	echo -e "|	                                             |"
	echo -e "|             \033[01;33mO que deseja fazer?                    \033[01;32m|"
	echo -e "|						     |"
	echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mMenu Principal                                \033[01;32m|"
	echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mAtiva Varejo Fácil!                           \033[01;32m|"
	echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mDesativa Varejo Fácil!                        \033[01;32m|"
	echo -e "|	                                             |"
	echo -e "#----------------------------------------------------#\033[01;37m"
	echo 
	read -re VAREJO
	case $VAREJO in
	0) echo -e && Menu ;; 
	1) echo
	   echo "Atualizando varejo"
       echo
       content="$(curl http://versoes.varejofacil.com/)"
       # content="$(wget http://versoes.varejofacil.com/)"
       versao="$(echo "$content" | grep -oP '(?<=<div id="mainContent" class="row" most-recent-build=").*?(?=">)')"
       ~/workspace/varejofacil/updateManual_v2 $versao
       docker exec varejofacil /opt/apache-activemq-5.15.6/bin/activemq start
       echo -e
       Menu ;;
    2) 
    	echo
        echo "Paralizando Varejofacil"
        echo
        docker stop varejofacil
        echo
        echo -e "Varejofacil Paralisado conforme solicitado !!!"
        Menu 
    ;;
    *)
        echo 
        echo -e "Opção Inválida!"
        echo
        VarejoFacil 
    ;;
    esac
}

AtualizaCredenciaisAWS() {
    echo 
    echo -e "\033[01;32m#----------------------------------------------------#"
    echo -e "|						     |"
    echo -e "| \033[01;33mQual Credencial deseja atualizar?                  \033[01;32m|"
    echo -e "|						     |"
    echo -e "| \033[01;37m00 \033[01;32m- \033[01;36mRetornar ao Menu Principal                    \033[01;32m|"
    echo -e "| \033[01;37m01 \033[01;32m- \033[01;36mCredencial CmAdmin                            \033[01;32m|"
    echo -e "| \033[01;37m02 \033[01;32m- \033[01;36mCredencial vfprod                             \033[01;32m|"
    echo -e "|						     |"
    echo -e "#----------------------------------------------------#\033[01;37m"
    echo -e 
    read -re RESPOSTA
    case $RESPOSTA in 
    1)
        echo
            aws sso login --profile CmAdmin
        echo
        echo 'Credencial CmAdmin configurada com sucesso!!'
        Menu
    ;;
    2)
        echo
            aws sso login --profile vfprod
        echo
        echo 'Credencial vfprod configurada com sucesso!!'
	    Menu
    ;;
    *)  
        echo
        Menu
    ;;
    esac  
}

AbreJupterNotebook () {
    cd /home/$USER/workspace/
    ./ProjetoPython.sh
}

echo
Menu