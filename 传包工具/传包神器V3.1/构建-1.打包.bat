@echo off
title ���ع����ű� Created by xudachao

if not defined MVN_HOME echo �����趨��������MVN_HOME������ %%MVN_HOME%%\bin; ��ӵ���������PATH�С� && pause && exit

echo Settings�ļ�λ��: %MVN_HOME%\conf\settings.xml
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
:: (1)��ȡ�����ļ��������
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (
    echo %%i | findstr "target_dir" >nul && echo "ɾ��Ŀ¼��%%j"
    echo %%i | findstr "target_dir" >nul && rmdir %%j /S /Q 2>nul
)

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: (2)��ȡ�����ļ�������ģ���
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
for /f "eol=# tokens=1,2 delims==" %%i in (����-����.ini) do (
    echo %%i | findstr "source_dir" >nul && echo.
    echo %%i | findstr "source_dir" >nul && echo "�����%%j"
    echo %%i | findstr "source_dir" >nul && ( call mvn clean install -Dmaven.test.skip=true -f %%j\pom.xml || pause && exit 1 )
)

:: ����ʱ��
set end_time=%date% %time%

echo ����ɹ�
echo.
echo ��ʼʱ�䣺%start_time%
echo ����ʱ�䣺%end_time%
echo.

pause

