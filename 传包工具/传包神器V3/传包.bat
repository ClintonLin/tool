@echo off
title 传包神器 Created by xudachao 00228543

:: --------------------------------------------------------------------------------
:: 参数设置 开始 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

:: 读取配置文件
for /f "eol=# tokens=1,2 delims==" %%i in (config.ini) do (set %%i=%%j)

:: set ip=127.0.0.1
:: set user=root
:: :: 密码中不支持特殊字符：<、>、|、&、^、%
:: set passwd=huawei123!
:: :: 搜索路径，多个路径以空格分开，支持环境变量
:: set serchPath="${OMU_HOME} ${DMU_HOME} ${MQ_HOME}/lib ${BMU_HOME}"

:: --------------------------------------------------------------------------------
:: 参数设置 结束 ------------------------------------------------------------------
:: --------------------------------------------------------------------------------

echo 配置信息：
echo     Ip       ：%ip%
echo     User     ：%user%
echo     Password ：%passwd%
echo     搜索路径 ：%serchPath%

echo.
echo 请确认信息是否正确，如果不正确，点X关闭窗口！！！否则任意键继续. . .
pause
echo.

:: 检查连通性
tools\plink.exe -pw %passwd% %user%@%ip% "echo ''> /dev/null"
if %errorlevel% neq 0 (
    echo.
    echo 连接失败，请检查配置是否正确。
    pause
    exit
)

:: 开始时间
set start_time=%date% %time%

:: 生成备份目录
for /f "delims=" %%i in ('tools\plink.exe -pw %passwd% %user%@%ip% "date +%%Y%%m%%d%%H%%M%%S"') do (set backupFolder=backup%%i)

set backupPathRemote=/home/replace_package/%backupFolder%
set backupPathLocal=package_backup\%ip%-%backupFolder%
echo 提示：软件包将同时在服务器和本地进行备份。
echo 服务器备份目录为 ：%backupPathRemote%
echo 本地备份目录为   ：%backupPathLocal%
echo.

:: 创建目录
tools\plink.exe -pw %passwd% %user%@%ip% "mkdir -p %backupPathRemote%/new && mkdir -p %backupPathRemote%/old"
mkdir %backupPathLocal%\new && mkdir %backupPathLocal%\old

echo =======================================================================
echo 上传新软件包：
echo =======================================================================
tools\pscp.exe -pw %passwd% package_send\* %user%@%ip%:%backupPathRemote%/new 2>nul
copy package_send\* %backupPathLocal%\new >nul 2>&1

tools\pscp.exe -pw %passwd% tools\replace_package.sh %user%@%ip%:%backupPathRemote% >nul 2>&1
copy tools\replace_package.sh %backupPathLocal% >nul 2>&1
echo.

echo =======================================================================
echo 查找并替换软件包：
echo =======================================================================
tools\plink.exe -pw %passwd% %user%@%ip% "bash %backupPathRemote%/replace_package.sh %serchPath% | tee -a %backupPathRemote%/replace_package.log"
echo.

echo =======================================================================
echo 下载旧软件包：
echo =======================================================================
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/old/*               %backupPathLocal%\old 2>nul
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/old_*               %backupPathLocal% >nul 2>&1
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/new_*               %backupPathLocal% >nul 2>&1
tools\pscp.exe -pw %passwd% %user%@%ip%:%backupPathRemote%/replace_package.log %backupPathLocal% >nul 2>&1
echo.

:: 结束时间
set end_time=%date% %time%

echo 恭喜，文件全部替换成功。
echo.
echo 开始时间：%start_time%
echo 结束时间：%end_time%
echo.

pause
