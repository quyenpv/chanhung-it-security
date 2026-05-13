@echo off
setlocal
:: Kiem tra quyen Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Dang chay voi quyen Quan tri vien...
) else (
    echo [LOI] Vui long chuot phai vao file .bat nay va chon "Run as Administrator".
    pause
    exit /b
)

:: Thiet lap ExecutionPolicy cho tat ca User (LocalMachine)
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

:: Chay file ChanHung_IT_Setup.ps1 nam cung thu muc voi file .bat
echo Dang thuc thi: ChanHung_IT_Setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ChanHung_IT_Install.ps1"

echo.
echo Da hoan thanh tat ca cac lenh.
pause