# Instalador do Migrador SysPDV -> VarejoFacil para Windows (chamado pelo instalar.bat, como administrador)
param([string]$Destino = "C:\migrador_syspdv_varejo", [string]$SenhaPostgres = "postgres")

# "Continue": no Windows PowerShell 5.1, com "Stop", qualquer texto de erro de um programa
# externo (ex.: taskkill "processo nao encontrado") derrubaria o instalador. Os erros que
# importam sao conferidos um a um (try/catch com -ErrorAction Stop e $LASTEXITCODE).
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"          # downloads bem mais rapidos
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$PastaScript = Split-Path -Parent $MyInvocation.MyCommand.Path      # ...\windows
$Origem      = Split-Path -Parent $PastaScript                        # raiz do migrador
$PY_VERSAO  = "3.12.10"
$PY_URL     = "https://www.python.org/ftp/python/$PY_VERSAO/python-$PY_VERSAO-amd64.exe"
$FB_URL     = "https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_x64.zip"
$FB_SHA256  = "707E05BAE8994B06CEC60815A292078DB82D8E75616F4DD514B7E417A3EE2137"
$PORTA      = 8020

function Passo([string]$t) { Write-Host ""; Write-Host ">> $t" -ForegroundColor Cyan }
function Ok([string]$t)    { Write-Host "   $t" -ForegroundColor Green }
function Aviso([string]$t) { Write-Host "   $t" -ForegroundColor Yellow }
function Falha([string]$t) { Write-Host ""; Write-Host "ERRO: $t" -ForegroundColor Red; exit 1 }

Write-Host "Instalando o Migrador SysPDV -> VarejoFacil em $Destino"

if (-not [Environment]::Is64BitOperatingSystem) {
    Falha "Windows 32 bits nao e suportado (o driver do PostgreSQL so existe para 64 bits)."
}

# ------------------------------------------------------------ 0. programas (instaladores na pasta Downloads)
# Instaladores: baixe do Drive interno; o script procura na pasta Downloads (e, se houver,
# na propria pasta windows\ ou na pasta "instaladores" de versoes anteriores).
$PastasInst = @((Join-Path $env:USERPROFILE "Downloads"), $PastaScript,
                (Join-Path $Destino "instaladores"), (Join-Path $Origem "instaladores"))
$PastaLogs = Join-Path $env:TEMP "migrador_instaladores"
New-Item -ItemType Directory -Force -Path $PastaLogs | Out-Null

function Achar-Instalador([string]$padrao) {
    foreach ($pasta in $PastasInst) {
        $achado = Get-ChildItem -Path $pasta -Filter $padrao -File -ErrorAction SilentlyContinue |
                  Sort-Object Name -Descending | Select-Object -First 1
        if ($achado) { return $achado }
    }
    return $null
}

function Instalar-Programa([string]$nome, [string]$padrao, [scriptblock]$jaInstalado, [scriptblock]$argumentos) {
    Passo "$nome"
    if (& $jaInstalado) { Ok "ja instalado - ignorado"; return }
    $arquivo = Achar-Instalador $padrao
    if (-not $arquivo) {
        Aviso "NAO instalado e nao achei o instalador ($padrao) na pasta Downloads."
        Aviso "Baixe do Drive interno para a pasta Downloads e rode o instalar.bat de novo. Pulando por enquanto."
        return
    }
    Aviso "instalando $($arquivo.Name) (aguarde, pode levar alguns minutos)..."
    $log = Join-Path $PastaLogs ($arquivo.BaseName + ".log")
    try {
        $proc = Start-Process -FilePath $arquivo.FullName -ArgumentList (& $argumentos $log) -Wait -PassThru -ErrorAction Stop
    } catch { Falha "nao consegui executar $($arquivo.Name): $($_.Exception.Message)" }
    if ($proc.ExitCode -notin @(0, 3010)) {
        Falha "$nome terminou com codigo $($proc.ExitCode). Log: $log"
    }
    if (& $jaInstalado) { Ok "instalado" }
    else { Falha "$nome parece nao ter sido instalado. Log: $log" }
}

$PF   = $env:ProgramFiles
$PF86 = ${env:ProgramFiles(x86)}

# Firebird 2.5 (servidor do SysPDV). Padrao do instalador: SuperServer como servico,
# iniciando com o Windows, usuario SYSDBA / senha masterkey.
Instalar-Programa "Firebird 2.5" "Firebird-*.exe" {
    (Test-Path "$PF86\Firebird\Firebird_2_5\bin\fbserver.exe") -or
    (Test-Path "$PF\Firebird\Firebird_2_5\bin\fbserver.exe") -or
    [bool](Get-Service -Name "Firebird*" -ErrorAction SilentlyContinue)
} { param($log) @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/LOG=`"$log`"") }

# PostgreSQL 15 (banco do VarejoFacil). Sem o pgAdmin e o StackBuilder do pacote:
# o pgAdmin tem instalador proprio logo abaixo.
Instalar-Programa "PostgreSQL 15" "postgresql-15*.exe" {
    (Test-Path "$PF\PostgreSQL\15\bin\postgres.exe") -or
    [bool](Get-Service -Name "postgresql*15*" -ErrorAction SilentlyContinue)
} { param($log) @("--mode", "unattended", "--unattendedmodeui", "minimal",
                  "--superpassword", "`"$SenhaPostgres`"", "--serverport", "5432",
                  "--enable-components", "server,commandlinetools",
                  "--disable-components", "pgAdmin,stackbuilder") }

# pgAdmin 4 (para consultar o banco)
Instalar-Programa "pgAdmin 4" "pgadmin4-*.exe" {
    (Test-Path "$PF\pgAdmin 4\runtime\pgAdmin4.exe") -or
    (Test-Path "$env:LOCALAPPDATA\Programs\pgAdmin 4\runtime\pgAdmin4.exe")
} { param($log) @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/ALLUSERS", "/LOG=`"$log`"") }

# ------------------------------------------------------------ 1. para o migrador
Passo "Parando o migrador, se estiver rodando"
$conexoes = Get-NetTCPConnection -LocalPort $PORTA -State Listen -ErrorAction SilentlyContinue
foreach ($c in $conexoes) { & taskkill.exe /PID $c.OwningProcess /T /F 2>$null | Out-Null }
& taskkill.exe /FI "WINDOWTITLE eq Servidor do Migrador SysPDV*" /T /F 2>$null | Out-Null
Ok "ok"

# ------------------------------------------------------------ 2. copia os arquivos
Passo "Copiando o migrador para $Destino"
$origemNorm  = (Resolve-Path $Origem).Path.TrimEnd('\')
$destinoNorm = $Destino.TrimEnd('\')
if ($origemNorm -ieq $destinoNorm) {
    Ok "ja esta na pasta de destino"
} else {
    try { New-Item -ItemType Directory -Force -Path $Destino -ErrorAction Stop | Out-Null }
    catch { Falha "nao consegui criar a pasta $Destino" }
    & robocopy.exe $Origem $Destino /E /XD .venv reports __pycache__ linux /XF migrador.log .migrador.pid /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Falha "nao consegui copiar os arquivos (robocopy codigo $LASTEXITCODE)" }
    Ok "arquivos copiados"
}
New-Item -ItemType Directory -Force -Path (Join-Path $Destino "reports") | Out-Null
# arquivos de versoes anteriores que mudaram de lugar (os scripts agora ficam em windows\).
# A pasta "instaladores" antiga, se existir, NAO e apagada (sao arquivos seus).
foreach ($velha in @("comandos\11_ajustes_pessoas", "comandos\29_ajustes_produto", "comandos\40_saldo_estoque", "comandos\41_movimentacao_custo", "instalador_windows", "instalador_linux", "linux",
                     "firebird_client_x64", "instalar.bat", "instalar-windows.bat", "instalar-windows.ps1",
                     "iniciar-app.bat", "parar-app.bat", "instalar.sh", "iniciar-app.sh")) {
    $p = Join-Path $Destino $velha
    if (Test-Path $p) { Remove-Item -Recurse -Force $p -ErrorAction SilentlyContinue; Ok "removido da versao antiga: $velha" }
}

# ------------------------------------------------------------ 3. Python 64 bits
Passo "Python 64 bits (usado pelo migrador)"
function Achar-Python {
    $candidatos = @()
    foreach ($v in @("312", "313", "311", "310")) {
        $candidatos += "$env:LOCALAPPDATA\Programs\Python\Python$v\python.exe"
        $candidatos += "$env:ProgramFiles\Python$v\python.exe"
    }
    foreach ($p in $candidatos) {
        if (Test-Path $p) {
            $ok = & $p -c "import sys, struct; print(int(sys.version_info >= (3, 10) and struct.calcsize(chr(80)) == 8))" 2>$null
            if ("$ok".Trim() -eq "1") { return $p }
        }
    }
    return $null
}
$py = Achar-Python
if (-not $py) {
    $local = Achar-Instalador "python-3*amd64*.exe"
    if ($local) {
        Aviso "Python 64 bits nao encontrado: instalando $($local.Name) ($($local.DirectoryName))"
        $instalador = $local.FullName
    } else {
        Aviso "Python 64 bits nao encontrado e sem instalador na pasta: baixando o Python $PY_VERSAO do python.org"
        $instalador = Join-Path $env:TEMP "python-$PY_VERSAO-amd64.exe"
        try { Invoke-WebRequest -Uri $PY_URL -OutFile $instalador -UseBasicParsing -ErrorAction Stop }
        catch { Falha "nao consegui baixar o Python ($PY_URL). Confira a internet." }
    }
    try {
        # como administrador: instala para todos os usuarios (C:\Program Files\Python312)
        $proc = Start-Process -FilePath $instalador -Wait -PassThru -ErrorAction Stop -ArgumentList @(
            "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_launcher=1", "Include_test=0", "Include_doc=0")
    } catch { Falha "nao consegui executar o instalador do Python" }
    if ($proc.ExitCode -notin @(0, 3010)) { Falha "o instalador do Python terminou com codigo $($proc.ExitCode)" }
    $py = Achar-Python
    if (-not $py) { Falha "o Python foi instalado mas nao foi encontrado" }
}
Ok "Python: $py"

# ------------------------------------------------------------ 4. ambiente do migrador
Passo "Criando o ambiente do migrador e instalando as dependencias (pode levar alguns minutos)"
Set-Location $Destino
$venvPy = Join-Path $Destino ".venv\Scripts\python.exe"
if (Test-Path $venvPy) {
    $bits = & $venvPy -c "import struct; print(struct.calcsize(chr(80)) * 8)" 2>$null
    if ("$bits".Trim() -ne "64") { Aviso "ambiente antigo nao e 64 bits: recriando"; Remove-Item -Recurse -Force (Join-Path $Destino ".venv") }
}
if (-not (Test-Path $venvPy)) {
    & $py -m venv .venv
    if ($LASTEXITCODE -ne 0) { Falha "nao consegui criar o ambiente .venv" }
}
& $venvPy -m pip install --upgrade pip -q --disable-pip-version-check
& $venvPy -m pip install -r requirements.txt -q --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { Falha "nao consegui instalar as dependencias (veja a mensagem acima)" }
Ok "dependencias instaladas"

# ------------------------------------------------------------ 5. client Firebird 64 bits
Passo "Verificando o client do Firebird 64 bits"
$fb64Instalado = "$env:ProgramFiles\Firebird\Firebird_2_5\bin\fbclient.dll"
$pastaLocal    = Join-Path $Destino "windows\firebird_client_x64"
if (Test-Path $fb64Instalado) {
    Ok "Firebird 2.5 64 bits instalado: $fb64Instalado"
} elseif (Test-Path (Join-Path $pastaLocal "fbclient.dll")) {
    Ok "client 64 bits do migrador ja existe: $pastaLocal"
} else {
    Aviso "O Firebird 2.5 instalado e 32 bits (ou nao foi achado em Arquivos de Programas)."
    Aviso "Baixando o pacote OFICIAL do Firebird 2.5.9 64 bits e copiando so as DLLs do client"
    Aviso "para $pastaLocal. O Firebird ja instalado nao e alterado."
    $zip = Join-Path $env:TEMP "Firebird-2.5.9-x64.zip"
    try { Invoke-WebRequest -Uri $FB_URL -OutFile $zip -UseBasicParsing -ErrorAction Stop }
    catch { Falha "nao consegui baixar o client do Firebird ($FB_URL)." }
    $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($hash -ne $FB_SHA256) { Falha "o arquivo do Firebird baixado nao confere (SHA256 $hash). Nada foi instalado." }
    New-Item -ItemType Directory -Force -Path $pastaLocal | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try {
        $arquivo = [IO.Compression.ZipFile]::OpenRead($zip)
        try {
            foreach ($e in $arquivo.Entries) {
                if ($e.FullName -match '^bin/(fbclient\.dll|msvcr80\.dll|msvcp80\.dll|Microsoft\.VC80\.CRT\.manifest|icu\w+\.dll)$') {
                    [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $pastaLocal $e.Name), $true)
                }
            }
        } finally { $arquivo.Dispose() }
    } catch { Falha "nao consegui extrair o client do Firebird: $($_.Exception.Message)" }
    Ok "client 64 bits copiado"
}
$teste = "$(& $venvPy -m app.verificar_fbclient)".Trim()
if ($teste -like "OK *") { Ok "o migrador carregou o client: $($teste.Substring(3))" }
else { Aviso "o migrador nao conseguiu carregar o client do Firebird: $teste" }

# ------------------------------------------------------------ 6. atalho
Passo "Criando o atalho 'Migrador SysPDV' na Area de Trabalho"
try {
    $shell = New-Object -ComObject WScript.Shell
    $atalho = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "Migrador SysPDV.lnk"))
    $atalho.TargetPath = Join-Path $Destino "windows\iniciar-app.bat"
    $atalho.WorkingDirectory = Join-Path $Destino "windows"
    $atalho.Description = "Migrador SysPDV -> VarejoFacil"
    $atalho.Save()
    Ok "atalho criado"
} catch { Aviso "nao consegui criar o atalho (abra $Destino\windows\iniciar-app.bat direto)" }

Write-Host ""
Write-Host "PRONTO! Migrador instalado em $Destino" -ForegroundColor Green
Write-Host "Para abrir: atalho 'Migrador SysPDV' na Area de Trabalho (ou $Destino\windows\iniciar-app.bat)."
