#!/bin/bash

# Cores Negrito

Preto="\e[1;30m"
Vermelho="\e[1;31m"
Verde="\e[1;32m"
Amarelo="\e[1;33m"
Azul="\e[1;34m"
Magenta="\e[1;35m"
Ciano="\e[1;36m"
Branco="\e[1;37m"


# Função para saudar o usuário
saudar() {
    # Pega a hora atual
    hora_atual=$(date +%H)

    # Define a saudação baseada na hora
    if [ "$hora_atual" -lt 12 ]; then
        saudacao="|       $Amarelo Bom dia$Branco! $Verde$USER$Branco, como está?      |"
    elif [ "$hora_atual" -lt 18 ]; then
        saudacao="|     $Amarelo Bom tarde$Branco! $Verde$USER$Branco, como está?      |"
    else
        saudacao="|     $Amarelo Bom noite$Branco! $Verde$USER$Branco, como está?      |"
    fi

    echo -e "$Branco"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo -e "$saudacao"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
}

# Função de encerramento do script
EncerraScript() {
    echo -e "Obrigado$Verde $USER$Branco, até breve!"
    echo ""
    exit
}

# Função para iniciar o Jupyter Notebook ou Jupyter Lab
IniciaJupyter() {
    # Inicializa o Conda
    eval "$(conda shell.bash hook)"
    conda init

    echo ""
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo "| Qual Jupyter o sr deseja iniciar?        |"
    echo "| 0. Retornar ao menu principal            |"
    echo "| 1. Jupyter Notebook                      |"
    echo "| 2. Jupyter Lab                           |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo ""

    while true; do
        read -re IniciaJupyter
        echo ""

        case $IniciaJupyter in
            0) main ;;
            1) echo "Iniciando Jupyter Notebook..."
                conda activate digital
                if command -v jupyter > /dev/null; then
                    echo ""
                    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
                    echo "| Em que diretório deseja que seja aberto? |"
                    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
                    echo ""
                    read -re dir_jupyter
                
                    if [ ! -d "$dir_jupyter" ]; then
                        echo "Diretório '$dir_jupyter' não encontrado!"
                        return
                    fi

                    cd "$dir_jupyter" || return
                    jupyter notebook
                    main
                else 
                    echo -e "$Vermelho Jupyter Notebook não está instalado! $Branco"
                fi
                break
                ;;
            2) echo "Iniciando Jupyter Lab..."
                conda activate digital
                if command -v jupyter > /dev/null; then
                    echo ""
                    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
                    echo "| Em que diretório deseja que seja aberto? |"
                    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
                    echo ""
                    read -re dir_jupyter
                
                    if [ ! -d "$dir_jupyter" ]; then
                        echo "Diretório '$dir_jupyter' não encontrado!"
                        return
                    fi

                    cd "$dir_jupyter" || return
                    jupyter lab
                    main
                else
                    echo "Jupyter Lab não está instalado."
                fi
                break
                ;;
            *) echo "Opção inválida. Por favor, escolha 0, 1 ou 2.";;
        esac
    done
}

# Função de atualização das credênciais de acesso a AWS
IniciaCredenciamentoAws() {
    echo -e "$Verde Atualizando credenciais de acesso a AWS ...$Branco"
    echo ""
        aws sso login --profile vfprod
    echo ""
    echo -e "$Ciano Credencial vfprod configurada com sucesso!! $Branco"
}

# Função de acesso a AWS
IniciaAws() {
    echo -e "$Verde Iniciando acesso a AWS ... $Branco"
    echo ""
    aws ssm start-session --target i-056f9ff343b3ac186 --profile vfprod
    echo -e "$Ciano Encerrando conexão com a AWS ... $Branco"
}

# Função de atualização das credências de acesso a Sustentação
IniciaCredenciamentoSustentacao() {
    echo -e "$Verde Atualizando credenciais de acesso a AWS ...$Branco"
    echo ""
        aws sso login --profile sustentacao-sdv-cmadmin
    echo ""
    echo -e "$Ciano Credencial vfprod configurada com sucesso!! $Branco"
}


# Função de conexão das bases de Sustentação
ConectaBancosSustentacao() {
    echo -e "$Verde Iniciando conexão ... $Branco"
    echo ""
    # aws ssm start-session --target mi-054088df9ef6a4626
    aws ssm start-session --target mi-054088df9ef6a4626 --document-name SustentacaoSDV-DB-StartPortForwardingSession --parameters "portNumber"="3307","localPortNumber"="3307" --profile sustentacao-sdv-cmadmin
    # aws ssm start-session --target mi-0be2cc3491a688e13 --document-name SustentacaoSDV-DB-StartPortForwardingSession --parameters "portNumber"="3307","localPortNumber"="3307" --profile sustentacao-sdv-cmadmin
    echo ""
}

# Função para iniciar o Pentaho
IniciaPentaho() {
    local pentaho_dir="$HOME/data-integration/"

    if [ -d "$pentaho_dir" ]; then
        cd "$pentaho_dir" || {
            echo "Erro ao acessar o diretório do Pentaho."
            return 1
        }
        source /etc/environment
        ./spoon.sh
    else
        echo "Diretório do Pentaho não encontrado: $pentaho_dir"
        return 1
    fi
}

# Função de criação de Banco
CriaBancoPostgres() {
    echo ""
    read -ep "Informe o nome do banco: " banco
    read -ep "Informe o caminho do arquivo: " arquivo
    echo ""

    # Verifica se há conexões ativas no banco
    if psql -h localhost -p 5432 -U postgres -d postgres -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$banco' AND state <> 'idle';" | grep -q 0; then
        echo ""
        psql -h localhost -p 5432 -U postgres -c "DROP DATABASE IF EXISTS $banco;"
        echo ""
        echo -e "$Verde Criando banco... $Branco"
        echo ""
        psql -h localhost -p 5432 -U postgres -c "CREATE DATABASE $banco WITH ENCODING='UTF8' TEMPLATE=template0 LC_COLLATE='C' LC_CTYPE='pt_BR.UTF-8' CONNECTION LIMIT=-1;"
        echo ""
        echo -e "$Ciano Restaurando banco... $Branco"
        pg_restore -h localhost -p 5432 -O -U postgres -d $banco $arquivo$banco.backup -v
        echo ""
    else
        echo "O BANCO ESTÁ SENDO UTILIZADO NO MOMENTO. POR GENTILEZA FECHE OS ACESSOS ANTES DE DROPAR O MESMO."
        echo ""
        return 1
    fi
}

BackupPostgres() {
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo "|                                          |"
    echo "|           O que deseja fazer?            |"
    echo "|                                          |"
    echo "| 00. Retornar ao Menu Principal           |"
    echo "| 01. Migração !                           |"
    echo "| 02. Validação !                          |"
    echo "| 03. Backup Simples !                     |"
    echo "|                                          |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo ""
    read -re escolha_backup_postgres

    case $escolha_backup_postgres in
        0) main;;
        1) echo ""
           read -rep 'Informe o nome do banco que deseja realizar o backup: ' banco
           read -rep 'Informe o caminho do arquivo: ' arquivo
           echo ""
           
           migrado="_migrado"
           dia=`date +%d%m`
           
           echo -e "$Verde Fazendo backup do banco... $Branco"
           
           PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -Fc -d $banco -f $arquivo$banco$migrado$dia.backup
           
           echo -e "$Ciano Backup concluído com sucesso !!! $Branco"
           echo ""
           echo -e "$Verde Atualizando Credenciais vfprod !!! $Branco"
           echo ""
               aws sso login --profile vfprod
           echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
           echo ""
           echo -e "$Ciano Credencial vfprod atualizadas com sucesso!! $Branco"
           echo ""
           echo -e "$Ciano ...Enviando backup para o S3... $Branco"
           echo ""
               cd $arquivo
               aws s3 cp $banco$migrado$dia.backup s3://migracao-mercado-varejofacil-databases/ --profile vfprod --quiet
#              aws s3 cp InsertSerrano.sql s3://migracao-mercado-varejofacil-databases/ --profile vfprod --quiet
           echo -e "$Ciano Envio de backup concluído !!! $Branco"
           echo ""
           echo -e "$Magenta Colar no Stage: $Branco" 
           echo ""
           echo -e "aws s3 cp s3://migracao-mercado-varejofacil-databases/$banco$migrado$dia.backup ."
#                   aws s3 cp s3://migracao-mercado-varejofacil-databases/InsertSerrano.sql .
           echo ""
           echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
           echo
           IniciaAws
           echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
           echo ""
           BackupPostgres ;;
        2) echo ""
           read -rep 'Informe o nome do banco para efetuar o backup: ' banco
           read -rep 'Informe o caminho do arquivo: ' arquivo
           
           validar='_validacao'

           echo ""
           echo -e "$Verde Fazendo backup do banco... $Branco"
           
           PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -Fc -d $banco -f $arquivo$banco$validar.backup
           
           echo ""
           echo -e "$Ciano Backup concluído com sucesso !!! $Branco"
           echo ""
           BackupPostgres ;;
        3) echo ""
           read -rep 'Informe o nome do banco para efetuar o backup: ' banco
           read -rep 'Informe o caminho do arquivo: ' arquivo
           echo ""
           echo -e "$Verde Fazendo backup do banco... $Branco"
           
           PGPASSWORD="postgres" pg_dump -h localhost -p 5432 -U postgres -O -Fc -d $banco -f $arquivo$banco.backup

           echo ""
           echo -e "$Ciano Backup concluído com sucesso !!! $Branco"
           echo ""
           BackupPostgres ;;
        *) echo ""
           echo -e "$Vermelho Opção inválida. Por favor, escolha uma opção válida $Branco"
           echo "" ;;
    esac
}

# Função para operações no Postgres
OperacoesPostgres() {
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo "|                                          |"
    echo "|           O que deseja fazer?            |"
    echo "|                                          |"
    echo "| 00. Retornar ao Menu Principal           |"
    echo "| 01. Abrir Postgres                       |"
    echo "| 02. Cria Banco de Dados !                |"
    echo "| 03. Backup Banco de Dados !              |"
    echo "|                                          |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo ""
    read -re escolha_postgres
    
    case $escolha_postgres in
        0) main ;;
        1) psql -h localhost -U postgres && main;;
        2) CriaBancoPostgres && OperacoesPostgres ;;
        3) BackupPostgres && OperacoesPostgres ;;
        *) echo ""
           echo -e "$Vermelho Opção inválida. Por favor, escolha uma opção válida $Branco"
           echo "" ;;
    esac
}

# Ambiente De Destino SysPDV
AmbienteSysPDV() {
    echo ""
    read -rep 'Informe o nome do cliente que deseja montar o ambiente: ' cliente
    echo ""

    if [ -z "$cliente" ]; then
        echo "$Vermelho Por favor, informe o nome do cliente! $Branco"
        return 1  # Retorna um código de erro para indicar que houve um problema
    fi

    cd ~/bd-clientes

    if [ -d "$cliente" ]; then
        echo -ne "$Verde O diretório '$cliente' já existe. Deseja substituí-lo? (s/n): $Branco"
        read substituir
        if [ "$substituir" != "s" ]; then
            echo ""
            echo -e "$Vermelho Operação cancelada! $Branco"
            echo ""
            PreparaAmbiente
            return 1
        fi
        rm -rf "$cliente"
    fi

    mkdir "$cliente"
    if [ $? -ne 0 ]; then
        echo ""
        echo -e "$Vermelho Erro ao criar o diretório para '$cliente'! $Branco"
        echo ""
        PreparaAmbiente
        return 1
    fi
    
    mkdir "$cliente"/origem
    mkdir "$cliente"/destino
    mkdir -p var/mssql/data/firebird/"$cliente"

    cp ~/bd-clientes/syspdv_srv_modelo-fdb var/mssql/data/firebird/"$cliente"/syspdv_srv_"$cliente".fdb
    chmod 777 var/mssql/data/firebird/"$cliente"/syspdv_srv_"$cliente".fdb

    if [ $? -ne 0 ]; then
        echo ""
        echo -e "$Vermelho Erro ao criar os subdiretórios para '$cliente'! $Branco"
        echo ""
        PreparaAmbiente
        return 1
    fi

    echo ""
    echo -e "$Ciano Ambiente para '$cliente' montado com sucesso em ~/bd-clientes/$cliente. $Branco"
    echo ""
    PreparaAmbiente
}

# Ambiente De Destino Varejofacil
AmbienteVarejofacil() {
    echo ""
    echo -e "...$Vermelho Ambiente em Desenvolvimento!! $Branco ..."
    echo ""
    PreparaAmbiente
}

# Preparando ambiente para a migração
PreparaAmbiente(){
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo "|                                          |"
    echo "|      Qual ambiente deseja preparar?      |"
    echo "|                                          |"
    echo "| 00. Retornar ao Menu Principal           |"
    echo "| 01. Firebird - SysPDV !                  |"
    echo "| 02. Varejofacil - Postgres !             |"
    echo "|                                          |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=#"
    echo ""
    read -re escolha_ambiente

    case $escolha_ambiente in
        0) main ;;
        1) AmbienteSysPDV && PreparaAmbiente ;;
        2) AmbienteVarejofacil && PreparaAmbiente ;;
        *) echo ""
           echo -e "$Vermelho Opção inválida. Por favor, escolha uma opção válida $Branco"
           echo "" ;;
    esac
}

# Subindo Varejofail pelo Docker
SubindoVarejofacil() {
    echo ""
    echo -e "...$Vermelho Ambiente em Desenvolvimento!! $Branco ..."
    echo ""
    PreparaAmbiente
}

BackupSistema() {
    # Definindo variáveis
    diretorio_backup="/home/steelfs/OneDrive/CasaMagalhaes/Backup"
    diretorio_destino="$diretorio_backup/steelfs"
    arquivo_zip="$diretorio_destino/backup.zip"
    
    # Lista de pastas a serem copiadas
    pastas=("Documentos" "Downloads" "workspace")
    
    # Removendo o arquivo zip antigo, se existir
    echo "Removendo arquivo zip antigo..."
    rm -f "$arquivo_zip"
    
    # Criando o diretório de backup
    echo "Criando diretório de backup..."
    mkdir -p "$diretorio_destino"
    
    # Criando o arquivo zip das pastas
    echo "Criando arquivo zip das pastas..."
    zip -r -v "$arquivo_zip" "${pastas[@]}"
    
    # Verificando se o arquivo zip foi criado com sucesso
    if [ $? -eq 0 ]; then
        echo "Arquivo zip criado com sucesso."
    else
        echo "Falha ao criar o arquivo zip."
        exit 1
    fi
    
    # Movendo o arquivo zip para o diretório de backup
    echo "Movendo o arquivo zip para o diretório de backup..."
    mv "$arquivo_zip" "$diretorio_backup"
    
    # Verificando se o arquivo zip foi movido com sucesso
    if [ $? -eq 0 ]; then
        echo "Arquivo zip movido para o diretório de backup com sucesso."
    else
        echo "Falha ao mover o arquivo zip para o diretório de backup."
        exit 1
    fi
    
    echo "Backup concluído com sucesso."
}

#Iniciando o IntelliJ
IniciaIntelliJ() {
    cd ~/ideaIU-2024.2.3/bin/
    sudo ./idea.sh
}


# Função para reiniciar o Sistema
ReiniciaSistema() {
    shutdown -r now 
}

# Função para o menu AWS
MenuAws() {
    echo ""
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#"
    echo "|                                           |"
    echo "|          Como posso lhe ajudar ?          |"
    echo "|                                           |"
    echo "|  0. Retornar ao Menu Principal            |"
    echo "|  1. Atualizar Credenciais AWS             |"
    echo "|  2. Acessar AWS                           |"
    echo "|  3. Atualizar Credenciais Sustentação     |"
    echo "|  4. Acessar Bancos Sustentação            |"
    echo "|                                           |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#"
    echo ""

    while true; do
        read -re option
        echo ""

        case $option in
             0) main ;;
             1) IniciaCredenciamentoAws && IniciaAws && main ;;
             2) IniciaAws && main ;;
             3) IniciaCredenciamentoSustentacao && ConectaBancosSustentacao && main ;;
             4) ConectaBancosSustentacao && main ;;
             *) echo ""
                echo -e "$Vermelho Opção inválida. Por favor, escolha uma opção válida $Branco"
                echo ""
                main ;;
        esac
    done
}

# Função para o menu principal
main() {
    saudar
    echo ""
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#"
    echo "|                                           |"
    echo "|          Como posso lhe ajudar ?          |"
    echo "|                                           |"
    echo "|  0. Sair do Sistema                       |"
    echo "|  1. Abrir Jupyter                         |"
    echo "|  2. Funções AWS                           |"
    echo "|  3. Iniciar IntelliJ                      |"
    echo "|  4. Iniciar Pentaho                       |"
    echo "|  5. Operações PostgreSQL                  |"
    echo "|  6. Preparando Ambiente Migrações         |"
    echo "|  7. Iniciando Varejofacil                 |"
    echo "| 98. Backup Sistema                        |"
    echo "| 99. Reiniciar o Sistema                   |"
    echo "|                                           |"
    echo "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#"
    echo ""

    while true; do
        read -re option
        echo ""

        case $option in
             0) EncerraScript ;;
             1) IniciaJupyter && main ;;
             2) MenuAws && main ;;
             3) IniciaIntelliJ && main ;;
             4) IniciaPentaho && main ;;
             5) OperacoesPostgres && main ;;
             6) PreparaAmbiente && main ;;
             7) SubindoVarejofacil && main ;;
            98) BackupSistema && main ;;
            99) ReiniciaSistema ;;
            *) echo ""
               echo -e "$Vermelho Opção inválida. Por favor, escolha uma opção válida $Branco"
               echo ""
               main ;;
        esac
    done
}

# Inicia o script
main
