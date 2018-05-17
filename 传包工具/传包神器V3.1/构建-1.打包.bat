@echo off
title 本地构建脚本 Created by xudachao

if not defined MVN_HOME echo 请先设定环境变量MVN_HOME，并将 %%MVN_HOME%%\bin; 添加到环境变量PATH中。 && pause && exit

echo Settings文件位置: %MVN_HOME%\conf\settings.xml
echo.

echo 请确认：
echo  (1)settings文件的配置与当前代码库路径相符。
echo  (2)settings文件中的updatePolicy为never，以确保本地仓库中的包不过期。
echo     如不是，修改为never后，需要完成一次全量的本地构建。
echo.
echo 如果不正确，点X关闭窗口！！！否则任意键继续. . .
echo.
pause

:: 开始时间
set start_time=%date% %time%
echo.&echo 开始打包. . .

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (1)读取配置文件，清理包
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
for /f "eol=# tokens=1,2 delims==" %%i in (构建-配置.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "删除目录：%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (2)读取配置文件，构建模块包
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
for /f "eol=# tokens=1,2 delims==" %%i in (构建-配置.ini) do (
    echo %%i | findstr "source_dir" >nul && echo.
    echo %%i | findstr "source_dir" >nul && echo "打包：%%j"
    echo %%i | findstr "source_dir" >nul && ( call mvn clean install -Dmaven.test.skip=true -f %%j\pom.xml || pause && exit 1 )
)

:: 结束时间
set end_time=%date% %time%

echo 打包成功
echo.
echo 开始时间：%start_time%
echo 结束时间：%end_time%
echo.

pause

