<#
.SYNOPSIS
  Sobe o ambiente Docker e constrói o banco do projeto (marco3) do zero.

.DESCRIPTION
  Faz exatamente o que o README descreve no passo a passo manual:
    1. docker compose down -v / up -d e espera o PostgreSQL ficar pronto
    2. cria o banco "marco3" (separado do banco de prática "matricula")
    3. copia as pastas sql\ e scripts\ para o contêiner e roda 01 a 09, em ordem
    4. confere as contagens esperadas (120 alunos, 300 matrículas, ...)
  Para no primeiro erro e mostra qual script falhou.

  Uso (PowerShell, na pasta do projeto):
    .\scripts\rodar_tudo.ps1

  Se o Windows bloquear a execução de scripts, rode assim:
    powershell -ExecutionPolicy Bypass -File .\scripts\rodar_tudo.ps1

.PARAMETER SemReset
  Não roda "docker compose down -v" (mantém o banco "matricula" do professor
  como está). O banco marco3 é sempre apagado e recriado.

.PARAMETER SemIndices
  Pula o 07_indices.sql, que leva alguns minutos (cria ~600 mil linhas de laboratório).

.PARAMETER GravarEvidencias
  Regrava docs\evidencias_indices.txt (saída do 07) e docs\evidencias_concorrencia.txt
  (saída do medir_concorrencia.sh), em UTF-8. Leva alguns minutos a mais.
#>
param(
    [switch]$SemReset,
    [switch]$SemIndices,
    [switch]$GravarEvidencias
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # acentos corretos na saída do psql
$OutputEncoding = [System.Text.Encoding]::UTF8

Set-Location (Split-Path $PSScriptRoot -Parent)            # raiz do projeto

function Passo($texto) { Write-Host ""; Write-Host ">> $texto" -ForegroundColor Cyan }
function Confere($acao) {
    if ($LASTEXITCODE -ne 0) { throw "FALHOU: $acao (codigo de saida $LASTEXITCODE)" }
}

# ---------------------------------------------------------------- 1. ambiente
Passo "1/5  Subindo o ambiente Docker"
if (-not $SemReset) { docker compose down -v; Confere "docker compose down -v" }
docker compose up -d
Confere "docker compose up -d"

Write-Host "Esperando o PostgreSQL aceitar conexoes (na primeira vez a carga do banco do professor leva alguns minutos)..."
$pronto = $false
$ErrorActionPreference = 'Continue'
for ($i = 0; $i -lt 90; $i++) {
    # -h 127.0.0.1: o servidor temporario da carga inicial so escuta por socket, nao por TCP
    docker exec bd2_postgres pg_isready -h 127.0.0.1 -U bd2 -d matricula *> $null
    if ($LASTEXITCODE -eq 0) { $pronto = $true; break }
    Start-Sleep -Seconds 5
}
$ErrorActionPreference = 'Stop'
if (-not $pronto) { throw "O PostgreSQL nao ficou pronto em 7,5 minutos. Veja: docker compose logs postgres" }
Write-Host "PostgreSQL pronto." -ForegroundColor Green

# ---------------------------------------------------------------- 2. banco marco3
Passo "2/5  Criando o banco marco3"
docker exec bd2_postgres psql -U bd2 -d matricula -q -c "DROP DATABASE IF EXISTS marco3 WITH (FORCE)"
Confere "DROP DATABASE marco3"
docker exec bd2_postgres psql -U bd2 -d matricula -q -c "CREATE DATABASE marco3 TEMPLATE template0"
Confere "CREATE DATABASE marco3"

# ---------------------------------------------------------------- 3. scripts SQL
Passo "3/5  Copiando e rodando os scripts SQL (01 a 09)"
docker cp sql bd2_postgres:/tmp/
Confere "docker cp sql"
docker cp scripts bd2_postgres:/tmp/
Confere "docker cp scripts"

$scripts = Get-ChildItem -Path sql -Filter '*.sql' | Sort-Object Name
foreach ($s in $scripts) {
    $nome = $s.Name
    if ($SemIndices -and $nome -like '07_*') { Write-Host "   [$nome] pulado (-SemIndices)"; continue }
    Write-Host "   [$nome] rodando..."
    $arq = "/tmp/sql/$nome"
    if ($nome -like '07_*' -and $GravarEvidencias) {
        docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -f $arq |
            Out-File -FilePath docs\evidencias_indices.txt -Encoding utf8
    }
    elseif ($nome -like '05_*' -or $nome -like '07_*') {
        # 05 (as 10 consultas) e 07 (laboratorio de indices) so imprimem resultados:
        # aqui rodam para provar que executam sem erro; o resultado se ve no pgAdmin / nas evidencias.
        docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f $arq | Out-Null
    }
    else {
        docker exec bd2_postgres psql -U bd2 -d marco3 -v ON_ERROR_STOP=1 -q -f $arq
    }
    Confere $nome
    Write-Host "   [$nome] OK" -ForegroundColor Green
}

# ---------------------------------------------------------------- 4. conferencia
Passo "4/5  Conferindo o resultado"
$sql = "SELECT 'alunos='||(SELECT count(*) FROM academico.tb_aluno)" +
       "||' turmas='||(SELECT count(*) FROM academico.tb_turma)" +
       "||' matriculas='||(SELECT count(*) FROM academico.tb_matricula)" +
       "||' com_nota='||(SELECT count(*) FROM academico.tb_historico WHERE media_geral IS NOT NULL)" +
       "||' policies='||(SELECT count(*) FROM pg_policies WHERE schemaname='academico')" +
       "||' trigger_vagas='||(SELECT count(*) FROM pg_trigger WHERE tgname='tg_valida_vaga')"
$obtido = (docker exec bd2_postgres psql -U bd2 -d marco3 -At -c $sql | Out-String).Trim()
Confere "conferencia final"
# 8 turmas = 7 da carga + a turma de teste CONC criada pelo 08
$esperado = "alunos=120 turmas=8 matriculas=300 com_nota=240 policies=10 trigger_vagas=1"
Write-Host "   obtido  : $obtido"
Write-Host "   esperado: $esperado"
if ($obtido -ne $esperado) { throw "As contagens nao batem com o esperado. Veja 'Problemas comuns' no README." }
Write-Host "   Contagens conferem." -ForegroundColor Green

# ---------------------------------------------------------------- 5. evidencias (opcional)
if ($GravarEvidencias) {
    Passo "5/5  Regravando a evidencia de concorrencia (1 a 2 minutos)"
    docker exec bd2_postgres bash /tmp/scripts/medir_concorrencia.sh |
        Out-File -FilePath docs\evidencias_concorrencia.txt -Encoding utf8
    Confere "medir_concorrencia.sh"
    Write-Host "   docs\evidencias_indices.txt e docs\evidencias_concorrencia.txt regravados." -ForegroundColor Green
}
else {
    Passo "5/5  Evidencias nao regravadas (use -GravarEvidencias para refazer)"
}

Write-Host ""
Write-Host "PRONTO. O banco marco3 esta no ar." -ForegroundColor Green
Write-Host "  pgAdmin : http://localhost:8080   (admin@iesb.br / admin)"
Write-Host "  psql    : docker exec -it bd2_postgres psql -U bd2 -d marco3"
Write-Host "  Em qualquer editor SQL, comece com:  SET search_path TO academico;"
