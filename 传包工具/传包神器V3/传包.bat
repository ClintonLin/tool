@echo off
title �������� Created by xudachao 00228543

:: --------------------------------------------------------------------------------
:: �������� ��ʼ ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: ��ȡ�����ļ�
for /f "eol=# tokens=1,2 delims==" %%i in (config.ini) do (set %%i=%%j)

:: set ip=127.0.0.1
:: set user=root
:: :: �����в�֧�������ַ���<��>��|��&��^��%
:: set passwd=huawei123!
:: :: ����·�������·���Կո�ֿ���֧�ֻ�������
:: set serchPath="${OMU_HOME} ${DMU_HOME} ${MQ_HOME}/lib ${BMU_HOME}"

:: --------------------------------------------------------------------------------
:: �������� ���� ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo ������Ϣ��
echo     Ip       ��%ip%
echo     User     ��%user%
echo     Password ��%passwd%
echo     ����·�� ��%serchPath%

echo.
echo ��ȷ����Ϣ�Ƿ���ȷ���������ȷ����X�رմ��ڣ������������������. . .
pause
echo.

:: �����ͨ��
tools\plink.exe -pw %passwd% %user%@%ip% "echo ''> /dev/null"
if %errorlevel% neq 0 (
    echo.
    echo ����ʧ�ܣ����������Ƿ���ȷ��
    pause
    exit
)

:: ��ʼʱ��
set start_time=%date% %time%

:: ���ɱ���Ŀ¼
for /f "delims=" %%i in ('tools\plink.exe -pw %passwd% %user%@%ip% "date +%%Y%%m%%d%%H%%M%%S"') do (set backupFolder=backup%%i)

set backupPathRemote=/home/replace_package/%backupFolder%
set backupPathLocal=package_backup\%ip%-%backupFolder%
echo ��ʾ���������ͬʱ�ڷ������ͱ��ؽ��б��ݡ�
echo ����������Ŀ¼Ϊ ��%backupPathRemote%
echo ���ر���Ŀ¼Ϊ   ��%backupPathLocal%
echo.

:: ����Ŀ¼
tools\plink.exe -pw %passwd% %user%@%ip% "mkdir -p %backupPathRemote%/new && mkdir -p %backupPathRemote%/old"
mkdir %backupPathLocal%\new && mkdir %backupPathLocal%\old

echo =======================================================================
echo �ϴ����������
echo =======================================================================
tools\pscp.exe -pw %passwd% package_send\* %user%@%ip%:%backupPathRemote%/new 2>nul
copy package_send\* %backupPathLocal%\new >nul 2>&1

tools\pscp.exe -pw %passwd% tools\replace_package.sh %user%@%ip%:%backupPathRemote% >nul 2>&1
copy tools\replace_package.sh %backupPathLocal% >nul 2>&1
echo.

echo =======================================================================
echo ���Ҳ��滻�������
echo =======================================================================
tools\plink.exe -pw %passwd% %user%@%ip% "bash %backupPathRemote%/replace_package.sh %serchPath% | tee -a %backupPathRemote%/replace_package.log"
echo.

echo =======================================================================
echo ���ؾ��������
echo =======================================================================
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/old/*               %backupPathLocal%\old 2>nul
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/old_*               %backupPathLocal% >nul 2>&1
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/new_*               %backupPathLocal% >nul 2>&1
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/replace_package.log %backupPathLocal% >nul 2>&1
echo.

:: ����ʱ��
set end_time=%date% %time%

echo ��ϲ���ļ�ȫ���滻�ɹ���
echo.
echo ��ʼʱ�䣺%start_time%
echo ����ʱ�䣺%end_time%
echo.

pause
