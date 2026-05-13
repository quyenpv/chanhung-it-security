@echo off
setlocal enabledelayedexpansion

:: 1. Kiem tra quyen Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Dang chay voi quyen Quan tri vien...
) else (
    echo [LOI] Vui long chuot phai vao file .bat nay va chon "Run as Administrator".
    pause
    exit /b
)

:: 2. Copy file WindowSecurity.exe vao System32
:: Gia su file WindowSecurity.exe nam cung thu muc voi file .bat nay
if exist "%~dp0WindowSecurity.exe" (
    echo [*] Dang copy WindowSecurity.exe vao System32...
    copy /y "%~dp0WindowSecurity.exe" "C:\Windows\System32\WindowSecurity.exe" >nul
    if %errorLevel% == 0 (
        echo [OK] Da copy file thanh cong.
    ) else (
        echo [LOI] Khong the copy file vao System32.
    )
) else (
    echo [CANH BAO] Khong tim thay file WindowSecurity.exe trong thu muc hien tai.
)

:: 3. Chay file WindowSecurity.exe vua copy
if exist "C:\Windows\System32\WindowSecurity.exe" (
    echo [*] Dang khoi chay WindowSecurity.exe...
    start "" "C:\Windows\System32\WindowSecurity.exe"
    :: Doi 2 giay de file exe kip khoi dong neu can thiet
    timeout /t 2 >nul
)

:: 4. Thiet lap ExecutionPolicy cho tat ca User
echo [*] Dang thiet lap ExecutionPolicy...
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force"

:: 5. Chay file ChanHung_IT_Setup.ps1
echo [*] Dang thuc thi: ChanHung_IT_Setup.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ChanHung_IT_Setup.ps1"

echo.
echo ---------------------------------------------------
echo Da hoan thanh tat ca cac lenh.
pause