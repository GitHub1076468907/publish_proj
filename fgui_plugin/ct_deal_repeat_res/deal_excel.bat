@ECHO off
REM 声明采用UTF-8编码
REM chcp 65001
REM echo 这是一个批处理文件
REM pause
cd /d %~dp0
::set date=%date:~0,4%%date:~5,2%%date:~8,2%
::创建日志文件
::echo %1 %2 %3 > %date%.log
py -3 excel_deal.py -a %1
timeout /t 2