@echo off
title ���ع����ű� Created by xudachao
setlocal enabledelayedexpansion

echo ��ʼ�ƶ��ļ�. . .

set package_send=%cd%\package_send
rmdir %package_send% /S /Q 2>nul
mkdir %package_send%       2>nul

for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "����Ŀ¼��%%j"
    echo %%i | findstr "target_dir" >nul && mkdir %%j 2>nul
    echo %%i | findstr "target_dir" >nul && set target_dirs=!target_dirs! %%j
)

for /f "delims=" %%i in ('dir /a-d-h/b/s %target_dirs% 2^>nul ^| findstr ".jar .war"') do (
    echo "�ƶ��ļ���%%i"
    move "%%i" %package_send% >nul
)

for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "ɾ��Ŀ¼��%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

echo.&echo �ƶ��ļ��ɹ���

echo.&echo 2����Զ��رգ�
ping -n 2 127.0.0.1 >nul

