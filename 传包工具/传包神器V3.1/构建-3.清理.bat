@echo off
title 本地构建脚本 Created by xudachao

echo 开始清理文件. . .

for /f "eol=# tokens=1,2 delims==" %%i in (构建-配置.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "删除目录：%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

echo.&echo 清理文件成功！

echo.&echo 2秒后自动关闭！
ping -n 2 127.0.0.1 >nul

