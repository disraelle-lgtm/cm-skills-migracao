1. Instalar o Dorcker;
    1.1 sudo apt-get update

    1.2 sudo apt-get install \
             apt-transport-https \
             ca-certificates \
             curl

    1.3 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -v   

    1.4 sudo apt-get update

    1.5 sudo apt-get install docker-ce

    1.6 sudo usermod -aG docker $USER
    
    1.7 sudo groupadd docker

    1.8 Reiniciar o computador
    
2. Crie um diretório varejofacil dentro de /home/$USER/workspace;

3. Copie os arquivos (DOCKER-FINAL.zip) para dentro do diretório varejofacil;

4. Descompacte o arquivo DOCKER_FINAL.zip
    sudo apt-get install unzip
    unzip DOCKER_FINAL.zip

5. Editar o arquivo pg_hba.conf
    5.1 sudo apt-get install vim
    5.2 sudo vi /etc/postgresql/12/main/pg_hba.conf

  #-----------------------------------------------------------------------------------#
  |      # Database administrative login by Unix domain socket                        |
  |      local   all             all                                trust             |
  |                                                                                   |
  |      # TYPE  DATABASE        USER            ADDRESS                 METHOD       |
  |                                                                                   |
  |      # "local" is for Unix domain socket connections only                         |
  |      host    all             all             127.0.0.1/32            trust        |
  |      host    all             all             172.16.13.0/24          trust        |
  |      host    all             all             172.16.17.0/24          trust        |
  |      host    all             all             172.17.0.0/16           trust        |
  |                                                                                   |
  |      local   all             all                                     peer         |
  |      # IPv4 local connections:                                                    |
  |      host    all             all             127.0.0.1/32            md5          |
  |      # IPv6 local connections:                                                    |
  |      host    all             all             ::1/128                 md5          |
  |      # Allow replication connections from localhost, by a user with the           |
  |      # replication privilege.                                                     |
  |      #local   replication     postgres                                peer        |
  |      #host    replication     postgres        127.0.0.1/32            md5         |
  |      #host    replication     postgres        ::1/128                 md5         |
  #-----------------------------------------------------------------------------------#

6. Editar o arquivo postgresql.conf
     6.1 sudo vim /etc/postgresql/9.6/main/postgresql.conf
  #-----------------------------------------------------------------------------------#
  |        #--------------------------------------------------------------------      |
  |        # CONNECTIONS AND AUTHENTICATION                                           |
  |        #--------------------------------------------------------------------      |
  |                                                                                   |
  |        # - Connection Settings -                                                  |
  |                                                                                   |
  |      listen_addresses = '*'                  # what IP address(es) to listen on;  |
  #-----------------------------------------------------------------------------------#

7. Dentro do diretório /home/$USER/workspace/varejofacil/DOCKER/IMAGE/:
    7.1 docker build -t varejofacil .
    7.2 docker images 
    7.3 docker run --name varejofacil -d -p 61616:61616 -p 8080:8080 -P -v /home/$USER/workspace/varejofacil:/app -v /home/$USER/workspace/varejofacil/migrations:/app/migrations -v /home/$USER/workspace/varejofacil/webapps:/usr/local/tomcat/webapps -v /home/$USER/workspace/varejofacil/work:/usr/local/tomcat/work -v /home/$USER/workspace/varejofacil/logs:/usr/local/tomcat/logs varejofacil
    7.4 docker ps

8. Alterar o arquivo configuracoes.properties
      8.1 sudo vim /home/$USER/workspace/varejofacil/configuracoes.properties
  #-----------------------------------------------------------------------------------#
  |   syspdvweb.jdbc.driverclass = org.postgresql.Driver                              |
  |   syspdvweb.hibernate.databasePlatform = org.hibernate.dialect.PostgreSQLDialect  |
  |   syspdvweb.jdbc.url = jdbc:postgresql://172.17.0.1:5432/panificadorakatiucia     |
  |   syspdvweb.jdbc.username = postgres                                              |
  |   syspdvweb.jdbc.password = postgres                                              |
  #-----------------------------------------------------------------------------------#

9. Inicie o serviço do varejo facil:
    docker start varejofacil

10. Inicie o serviço do activemq:
    docker exec varejofacil /opt/apache-activemq-5.15.6/bin/activemq start

11. NO browser acesse o endereço:
        localhost:8080