@echo off
cd /d F:\lb_lifeform
set http_proxy=http://127.0.0.1:7897
set https_proxy=http://127.0.0.1:7897
git push origin main 2>&1
echo EXITCODE=%ERRORLEVEL%
