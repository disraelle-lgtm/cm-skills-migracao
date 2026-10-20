@echo off
title Menu AWS

:menu
cls
echo Menu AWS
echo.
echo 1 - AWS (Migracao vfprod)
echo 2 - AWS (Sustentacao cmadmin)
echo 5 - Pentaho
echo 7 - Firebird
echo 8 - PostgreSQL 12
echo 9 - Sair
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto menumigracao
if %opcao%==2 goto menucmadmin
if %opcao%==5 goto menupentaho
if %opcao%==7 goto menufirebird
if %opcao%==8 goto menupost
if %opcao%==9 goto sair


echo Opcao invalida. Tente novamente.
goto menu


:menumigracao
cls
echo AWS (Migracao vfprod)
echo.
echo 1 - Autenticar AWS Migracao
echo 2 - Entrar  no AWS Migracao
echo 3 - Voltar Menu inicial
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto autenticar_migracao
if %opcao%==2 goto ssm_migracao
if %opcao%==3 goto menu

:autenticar_migracao
aws sso login --profile vfprod
goto menumigracao

:ssm_migracao
aws ssm start-session --target i-056f9ff343b3ac186 --profile vfprod
goto menumigracao

:menu
goto menu


:menucmadmin
cls
echo AWS (Sustentacao cmadmin)
echo.
echo 1 - Autenticar AWS Sustentacao
echo 2 - Entrar  no AWS Sustentacao
echo 3 - Voltar Menu inicial
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto autenticar_cmadmin
if %opcao%==2 goto ssm_cmadmin
if %opcao%==3 goto menu

:autenticar_cmadmin
aws sso login --profile sustentacao-sdv-cmadmin
goto menucmadmin

:ssm_cmadmin
aws ssm start-session --target mi-054088df9ef6a4626 --document-name SustentacaoSDV-DB-StartPortForwardingSession --parameters "portNumber"="3307","localPortNumber"="3307" --profile sustentacao-sdv-cmadmin
goto menucmadmin

:menu
goto menu


:menufirebird
cls
echo Menu Firebird
echo.
echo 1 - Fazer backup
echo 2 - Manutencao Gfix
echo 3 - Manutencao Gbak
echo 4 - Voltar Menu inicial
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto backup_fire
if %opcao%==2 goto manutencao_1_fire
if %opcao%==3 goto manutencao_2_fire
if %opcao%==4 goto menu

:backup_fire
cd:
rd c:\syspdv\BACKUP_SRV /Y
md c:\syspdv\BACKUP_SRV

Echo.
Echo.
Echo.    COPIANDO ARQUIVO syspdv_srv.fdb, POR FAVOR AGUARDE...
Echo.
Echo.

copy "C:\syspdv\syspdv_srv.fdb" "c:\syspdv\BACKUP_SRV\Syspdv_srv_Backup.fdb" /y
pause

Echo.
Echo.
Echo.    COPIANDO ARQUIVO Gbak, Gfix e fbcliente.dll POR FAVOR AGUARDE...
Echo.
Echo.

copy "C:\Program Files (x86)\Firebird\Firebird_2_5\bin\fbclient.dll" "c:\syspdv\" /y
copy "C:\Program Files (x86)\Firebird\Firebird_2_5\bin\gfix.exe" "c:\syspdv\" /y
copy "C:\Program Files (x86)\Firebird\Firebird_2_5\bin\gbak.exe" "c:\syspdv\" /y
pause
goto menufirebird

:manutencao_1_fire
Echo.
Echo.
Echo.    SETANDO USUARIO E SENHA...
Echo.
Echo.
      
	cd..
	cd..
	cd Syspdv
	set isc_user=SYSDBA
	set isc_password=masterkey
                     
Echo.
Echo.     
Echo.   PROCESSANDO gfix -v -f ...
Echo.
Echo.

	gfix -v -f -user sysdba -password masterkey SYSPDV_SRV.FDB

pause

Echo.
Echo.     
Echo.   PROCESSANDO gfix -m -f -i ...
Echo.
Echo.

	gfix -m -f -i -user sysdba -password masterkey SYSPDV_SRV.FDB
pause
goto menufirebird


:manutencao_2_fire
Echo.
Echo.
Echo.    SETANDO USUARIO E SENHA...
Echo.
Echo.
      
	cd..
	cd..
	cd Syspdv
	set isc_user=SYSDBA
	set isc_password=masterkey
                     
Echo.
Echo.     
Echo.   PROCESSANDO gbak -b -v -i -g -l ...
Echo.
Echo.

	gbak -b -v -i -g -l -user sysdba -password masterkey SYSPDV_SRV.FDB SYSPDV_SRV.FBK

Echo.
Echo.
Echo.   BACKUP CONCLUIDO...
Echo.
Echo.
Echo.   RENOMEANDO BANCO DE DADOS...
Echo.
Echo.

	ren SYSPDV_SRV.FDB SYSPDV_SRV_BACKUP.FDB

Echo.
Echo.
Echo.   PROCESSANDO gbak -c -v -i ...
Echo.
Echo.

	gbak -c -v -i -user sysdba -password masterkey SYSPDV_SRV.GBK SYSPDV_SRV.FDB

Echo.
Echo.
Echo.    REPARO DO BANCO DE DADOS CONCLUIDO COM SUCESSO.
Echo.
pause         
goto menufirebird

:menupentaho
cls
echo Menu Pentaho
echo.
echo 1 - Abrir Pentaho
echo 2 - Voltar Menu inicial
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto abrir_pentaho
if %opcao%==2 goto menu

:abrir_pentaho
start "" "C:\Users\[usuario]\data-integration\Spoon.bat"
goto menu



:menupost
cls
echo Menu PostgreSQL 12
echo.
echo 1 - Fazer backup
echo 2 - Restaurar Backup
echo 3 - Deletar Banco
echo 4 - Voltar Menu inicial
echo.
set /p opcao=Escolha uma opcao: 

if %opcao%==1 goto backup_post
if %opcao%==2 goto restore_post
if %opcao%==3 goto delete_post
if %opcao%==4 goto menu

:backup_post
goto menupost

:restore_post
goto menupost

:delete_post
goto menupost

:sair
exit