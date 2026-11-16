@echo off
REM Abre o Painel Dev. %~dp0 = pasta deste .bat, entao funciona de qualquer lugar.
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0painel.ps1"
