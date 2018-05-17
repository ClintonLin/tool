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

echo 开始清理文件. . .

rmdir %java_src%\bmu            /S /Q 2>nul
rmdir %java_src%\dmu            /S /Q 2>nul
rmdir %java_src%\omu            /S /Q 2>nul
rmdir %java_src%\virtualization /S /Q 2>nul

rmdir %java_src%\..\bmu            /S /Q 2>nul
rmdir %java_src%\..\dmu            /S /Q 2>nul
rmdir %java_src%\..\omu            /S /Q 2>nul
rmdir %java_src%\..\virtualization /S /Q 2>nul

echo.&echo 清理文件成功！

echo.&echo 2秒后自动关闭！
ping -n 2 127.0.0.1 >nul
