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

if not defined MVN_HOME echo �����趨��������MVN_HOME������ %%MVN_HOME%%\bin; ��ӵ���������PATH�С� && pause && exit

echo Settings�ļ�λ��: %MVN_HOME%\conf\settings.xml
echo Java����·��:     %java_src%
echo.

echo ��ȷ�ϣ�
echo  (1)settings�ļ��������뵱ǰ�����·�������
echo  (2)settings�ļ��е�updatePolicyΪnever����ȷ�����زֿ��еİ������ڡ�
echo     �粻�ǣ��޸�Ϊnever����Ҫ���һ��ȫ���ı��ع�����
echo.
echo �������ȷ����X�رմ��ڣ������������������. . .
echo.
pause

:: ��ʼʱ��
set start_time=%date% %time%
echo.&echo ��ʼ���. . .

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (1)�����
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
:: (2)�����ӿڰ�
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
:: (3)����ģ���
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
cd /d %java_src%\com.huawei.cie.dmu\com.huawei.cie.dmu.vap
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.omu\com.huawei.cie.omu.vm
call mvn clean install -Dmaven.test.skip=true || pause && exit

cd /d %java_src%\com.huawei.cie.view\com.huawei.cie.view.vm
call mvn clean install -Dmaven.test.skip=true || pause && exit

:: ����ʱ��
set end_time=%date% %time%

echo ����ɹ�
echo.
echo ��ʼʱ�䣺%start_time%
echo ����ʱ�䣺%end_time%
echo.

pause
