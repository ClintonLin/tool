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

if not defined MVN_HOME echo 请先设定环境变量MVN_HOME，并将 %%MVN_HOME%%\bin; 添加到环境变量PATH中。 && pause && exit

echo Settings文件位置: %MVN_HOME%\conf\settings.xml
echo Java代码路径:     %java_src%
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
:: (1)清理包
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
rmdir %java_src%\bmu            /S /Q 2>nul
rmdir %java_src%\dmu            /S /Q 2>nul
rmdir %java_src%\omu            /S /Q 2>nul
rmdir %java_src%\virtualization /S /Q 2>nul

rmdir %java_src%\..\bmu            /S /Q 2>nul
rmdir %java_src%\..\dmu            /S /Q 2>nul
rmdir %java_src%\..\omu            /S /Q 2>nul
rmdir %java_src%\..\virtualization /S /Q 2>nul

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (2)构建接口包
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
cd /d %java_src%\com.huawei.cie.support\com.huawei.cie.vap.api
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.sdk\com.huawei.cie.dmu.sdk\com.huawei.cie.dmu.vap.channel.api
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.sdk\com.huawei.cie.dmu.sdk\com.huawei.cie.dmu.vap.task.api
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.sdk\com.huawei.cie.omu.sdk\com.huawei.cie.omu.vm.api
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.sdk\com.huawei.cie.omu.sdk\com.huawei.cie.omu.vm.intf
call mvn clean install -Dmaven.test.skip=true || pause && exit

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (3)构建模块包
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
cd /d %java_src%\com.huawei.cie.dmu\com.huawei.cie.dmu.vap
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.omu\com.huawei.cie.omu.vm
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.view\com.huawei.cie.view.vm
call mvn clean install -Dmaven.test.skip=true || pause && exit

:: 结束时间
set end_time=%date% %time%

echo 打包成功
echo.
echo 开始时间：%start_time%
echo 结束时间：%end_time%
echo.

pause
