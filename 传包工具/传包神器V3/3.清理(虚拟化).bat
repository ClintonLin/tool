@echo off
title ���ع����ű� Created by xudachao 00228543

:: --------------------------------------------------------------------------------
:: �������� ��ʼ ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: ��ȡ�����ļ�
for /f "eol=# tokens=1,2 delims==" %%i in (config.ini) do (set %%i=%%j)

:: :: javaԴ��·��
:: set java_src=D:\TeamResource\CODE_I2000_Main\PublishVersion_Build\SRC_Code\CIE\source\Java

:: --------------------------------------------------------------------------------
:: �������� ���� ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo ��ʼ�����ļ�. . .

rmdir %java_src%\bmu            /S /Q 2>nul
rmdir %java_src%\dmu            /S /Q 2>nul
rmdir %java_src%\omu            /S /Q 2>nul
rmdir %java_src%\virtualization /S /Q 2>nul

rmdir %java_src%\..\bmu            /S /Q 2>nul
rmdir %java_src%\..\dmu            /S /Q 2>nul
rmdir %java_src%\..\omu            /S /Q 2>nul
rmdir %java_src%\..\virtualization /S /Q 2>nul

echo.&echo �����ļ��ɹ���

echo.&echo 2����Զ��رգ�
ping -n 2 127.0.0.1 >nul
