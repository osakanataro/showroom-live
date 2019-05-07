@echo off

title ShowroomLive:Ringo Kujo
:startloop

powershell -sta -ExecutionPolicy Unrestricted -File %0\..\showroom-live.ps1 -roomurl "https://www.showroom-live.com/ringo-005" -record 

goto startloop
