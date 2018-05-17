@echo off
title 本地构建脚本 Created by xudachao 00228543

:: --------------------------------------------------------------------------------
:: 参数设置 开始 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: 读取配置文件
for /f "eol=# tokens=1,2 delims==" %%i in (config.ini) do (set %%i=%%j)

:: :: java源码路径
:: set java_src=D:\TeamResource\CODE_I2000_Main\PublishVersion_Build\SRC_Code\CIE\source\Java

:: --------------------------------------------------------------------------------
:: 参数设置 结束 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo 开始移动文件. . .

set packageDir=%java_src%\..
set targetDir=%cd%\package_send

rmdir %targetDir% /S /Q 2>nul
mkdir %targetDir%       2>nul

mkdir %packageDir%\bmu            2>nul
mkdir %packageDir%\dmu            2>nul
mkdir %packageDir%\omu            2>nul
mkdir %packageDir%\virtualization 2>nul

for /f "delims=" %%i in ('dir /a-d-h/b/s %packageDir%\bmu %packageDir%\dmu %packageDir%\omu %packageDir%\virtualization 2^>nul') do (echo %%i
    move "%%i" %targetDir% >nul
)

rmdir %packageDir%\bmu            /S /Q 2>nul
rmdir %packageDir%\dmu            /S /Q 2>nul
rmdir %packageDir%\omu            /S /Q 2>nul
rmdir %packageDir%\virtualization /S /Q 2>nul

echo.&echo 移动文件成功！

echo.&echo 2秒后自动关闭！
ping -n 2 127.0.0.1 >nul
