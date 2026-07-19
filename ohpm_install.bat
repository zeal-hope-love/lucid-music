@echo off
cd /d "c:\Users\PoXia\DevEcoStudioProjects\lucid_music"
"C:\Program Files\Huawei\DevEco Studio\tools\ohpm\bin\ohpm.bat" install > ohpm_log.txt 2>&1
echo EXIT=%errorlevel%
