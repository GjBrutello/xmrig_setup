��    
 @echo off 
 cd /d "%~dp0"
 Title xmrig-proxy service
 
 :init
 setlocal DisableDelayedExpansion
 set "batchPath=%~0"
 for %%k in (%0) do set batchName=%%~nk
 set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
 setlocal EnableDelayedExpansion
 
 where WScript >NUL
 if not %errorlevel% == 0 (
	echo ERROR: This script requires "WScript" utility to work correctly
	pause
	exit /b 1
 )
  
 :checkPrivileges
 NET FILE 1>NUL 2>NUL
 if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )
 
 :getPrivileges
 if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)
 ECHO Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
 ECHO args = "ELEV " >> "%vbsGetPrivileges%"
 ECHO For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
 ECHO args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
 ECHO Next >> "%vbsGetPrivileges%"
 ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
 "%SystemRoot%\System32\WScript.exe" "%vbsGetPrivileges%" %*
 exit /B

 :gotPrivileges
 color 1F
 setlocal & pushd .
 cd /d %~dp0
 if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

 rem command line arguments
 set WALLET=%1
 rem this one is optional
 set EMAIL=%2
 
 rem checking prerequisites
 
 if [%WALLET%] == [] (
	echo.
	color 0c
	echo ERROR: Please specify your wallet address
	echo.
	echo Script usage: setup_%prx%.cmd ^[wallet address^] ^<your email address^>
	echo.
	pause
	exit /b 1
 )
 for /f "delims=." %%a in ("%WALLET%") do set WALLET_BASE=%%a
 call :strlen "%WALLET_BASE%", WALLET_BASE_LEN
 if %WALLET_BASE_LEN% == 106 goto WALLET_LEN_OK
 if %WALLET_BASE_LEN% ==  95 goto WALLET_LEN_OK
 echo ERROR: Wrong wallet address length (should be 106 or 95): %WALLET_BASE_LEN%
 exit /b 1
 
 :WALLET_LEN_OK
 
 where powershell >NUL
 if not %errorlevel% == 0 (
	echo ERROR: This script requires "powershell" utility to work correctly
	exit /b 1
 )
 
 where sc >NUL
 if not %errorlevel% == 0 (
	echo ERROR: This script requires "sc" utility to work correctly
	exit /b 1
 )
 
 set flzip=xmrig-proxy.zip
 set lcpath=xmrig_proxy
 set zipunp=7za.exe
 set nssmsvc=nssm.zip
 set prx=xmrig_proxy
 
 :Removing_previous_xmrig-proxy
 echo.
 echo [*] Removing previous "%prx%" service (if exist) 
 sc stop %prx%
 sc delete %prx%
 taskkill /f /im xmrig-proxy.exe
 
 :Downloading
 echo [*] Looking for the latest version of xmrig-proxy
 for /f tokens^=2^ delims^=^" %%a IN ('powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $str = $wc.DownloadString('https://github.com/xmrig/xmrig-proxy/releases/latest'); $str | findstr msvc-win64.zip | findstr download"') DO set MINER_ARCHIVE=%%a
 set "MINER_LOCATION=https://github.com%MINER_ARCHIVE%"
 
 
 echo [*] Downloading "%MINER_LOCATION%" to ".\%flzip%"
 powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%MINER_LOCATION%', '.\%flzip%')"
 if errorlevel 1 (
   echo ERROR: Can't download "%MINER_LOCATION%" to ".\%flzip%"
   exit /b 1
 
 )
 :Unpacking
 echo [*] Unpacking .\%flzip% to .\%lcpath%
 %zipunp% e -y -o%lcpath% %flzip% >NUL
 if errorlevel 1 (
   echo [*] Downloading %zipunp% to %cd%
   powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe', '.\7za.exe')"
   if errorlevel 1 (
     echo ERROR: Can't download %zipunp% to "%cd%"
     exit /b 1
  )
 echo [*] Unpacking .\%flzip% to .\%lcpath%
 %zipunp% e -y -o%lcpath% %flzip% >NUL
 if errorlevel 1 (
   echo ERROR: Can't unpack %flzip% to %lcpath%
   exit /b 1
  )
  del /f /q %zipunp%
 )
 del /f /q %flzip%
 
 :del_empty_xmrig_folder
 for /F "tokens=*" %%I in ('dir /a:d-s-h /b .\%lcpath% ^| findstr /B /I xmrig-pro') do (
  :: echo [*] Removing Directory ".\%lcpath%\%%I" 
  rmdir /s /q ".\%lcpath%\%%I"
 )
 
 echo [*] Checking if ".\%lcpath%\xmrig-proxy.exe" works fine ^(and not removed by antivirus software^)
 powershell -Command "$out = cat '.\%lcpath%\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 0,'} | Out-String; $out | Out-File -Encoding ASCII '.\%lcpath%\config.json'" 
 .\%lcpath%\xmrig-proxy.exe --help >NUL
 if %ERRORLEVEL% equ 0 goto MINER_OK
 
 :MINER_OK
 echo [*] File ".\%lcpath%\xmrig-proxy.exe" is OK
 set PORT=10128
 for /f "tokens=*" %%a in ('powershell -Command "hostname | %%{$_ -replace '[^a-zA-Z0-9]+', '_'}"') do set PASS=%%a
 if [%PASS%] == [] (
   set PASS=na
 )
 if not [%EMAIL%] == [] (
   set "PASS=%PASS%:%EMAIL%"
 )
 
 powershell -Command "$out = cat '%lcpath%\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"gulf.moneroocean.stream:%PORT%\",'} | Out-String; $out | Out-File -Encoding ASCII '%lcpath%\config.json'" 
 powershell -Command "$out = cat '%lcpath%\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%lcpath%\config.json'" 
 powershell -Command "$out = cat '%lcpath%\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%lcpath%\config.json'" 
 
 
 rem preparing script
 (
 echo @echo off
 echo echo.
 echo tasklist /fi "imagename eq xmrig-proxy.exe" ^| find ":" ^>NUL
 echo if errorlevel 1 goto ALREADY_RUNNING
 echo start /low %%~dp0xmrig-proxy.exe %%^*
 echo goto EXIT
 echo :ALREADY_RUNNING
 echo echo "%prx%" is already running and refusing to run another one.
 echo echo Run the console command "sc stop %prx%" first if you want to stop background "%prx%" service.
 echo echo Run the console command "sc delete %prx%" if you want to delete the "%prx%" service.
 echo echo.
 echo @pause
 ) > "%lcpath%\xmrig-proxy_launcher.cmd"
 
 :ADMIN_MINER_SETUP
 
 echo [*] Downloading tools "%nssmsvc%" to create "%prx%" service
 powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/nssm.zip', '.\nssm.zip')"
 if errorlevel 1 (
  echo ERROR: Can't download tools to make "%prx%" service
  exit /b 1
 )
 
 echo [*] Unpacking .\%nssmsvc% to .\%lcpath%
 powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('.\nssm.zip', '%lcpath%')"
 if errorlevel 1 (
  echo [*] Downloading %zipunp% to "%cd%"
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe', '.\7za.exe')"
  if errorlevel 1 (
    echo ERROR: Can't download "%zipunp%" to "%cd%"
    exit /b 1
  )
  echo [*] Unpacking .\%nssmsvc% to .\%lcpath%
  %zipunp% x -y -o%lcpath% %nssmsvc% >NUL
  if errorlevel 1 (
    echo ERROR: Can't unpack "%nssmsvc%" to "%lcpath%"
    exit /b 1
  )
  del /f /q %zipunp%
 )
 del /f /q %nssmsvc%
 
 rem Creating "%prx%" service
 echo [*] Creating "%prx%" service
 powershell -command $p = $pwd.path;".\%lcpath%\nssm.exe" install %prx% "$p\%lcpath%\xmrig-proxy.exe";start-sleep 2;".\%lcpath%\nssm.exe" set %prx% DisplayName "xmrig_proxy service";".\%lcpath%\nssm.exe" set %prx% Description '@nlasvc.dll,-2'
 if errorlevel 1 (
   echo ERROR: Can't create "%prx%" service
   exit /b 1
 )
 echo [*] Starting "%prx%" service
 PING -n 2 -w 2000 127.0.0.1 > nul
 sc start %prx%
 PING -n 2 -w 2000 127.0.0.1 > nul
 if errorlevel 1 (
   echo ERROR: Can't start "%prx%" service
   echo.
   echo Please reboot system if "%prx%" service is not activated yet
   exit /b 1
 )
 
 :OK
 color 17
 echo.
 echo [*] Setup complete
 echo [*] Deleting installer file
 echo.
 ::pause
 color 07
 del /f /q ".\%prx%_installer.cmd"
 
 
 :strlen string len
 setlocal EnableDelayedExpansion
 set "token=#%~1" & set "len=0"
 for /L %%A in (12,-1,0) do (
   set/A "len|=1<<%%A"
   for %%B in (!len!) do if "!token:~%%B,1!"=="" set/A "len&=~1<<%%A"
 )
 endlocal & set %~2=%len%
 exit /b
 