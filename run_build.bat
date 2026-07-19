@echo off
cd /d "C:\Users\PoXia\DevEcoStudioProjects\lucid_music"
"C:\Program Files\Huawei\DevEco Studio\tools\node\node.exe" "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default > build_log2.txt 2>&1
echo EXIT=%errorlevel%
