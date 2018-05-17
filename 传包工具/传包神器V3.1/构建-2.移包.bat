@echo off
title 本地构建脚本 Created by xudachao
setlocal enabledelayedexpansion

echo 开始移动文件. . .

set package_send=%cd%\package_send
rmdir %package_send% /S /Q 2>nul
mkdir %package_send%       2>nul

for /f "eol=# tokens=1,2 delims==" %%i in (构建-配置.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "创建目录：%%j"
    echo %%i | findstr "target_dir" >nul && mkdir %%j 2>nul
    echo %%i | findstr "target_dir" >nul && set target_dirs=!target_dirs! %%j
)

for /f "delims=" %%i in ('dir /a-d-h/b/s %target_dirs% 2^>nul ^| findstr ".jar .war"') do (
    echo "移动文件：%%i"
    move "%%i" %package_send% >nul
)

for /f "eol=# tokens=1,2 delims==" %%i in (构建-配置.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "删除目录：%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

echo.&echo 移动文件成功！

echo.&echo 2秒后自动关闭！
ping -n 2 127.0.0.1 >nul

