@echo off
title ���ع����ű� Created by xudachao

echo ��ʼ�����ļ�. . .

for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "ɾ��Ŀ¼��%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

echo.&echo �����ļ��ɹ���

echo.&echo 2����Զ��رգ�
ping -n 2 127.0.0.1 >nul

