@echo off
rem Corre update.ps1 sin cambiar la politica de ejecucion de Windows (solo para este proceso).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1" %*
