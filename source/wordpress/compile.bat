@echo off
rem fpc must be in PATH, e.g. C:\lazarus\fpc\3.2.2\bin\x86_64-win64
if not exist lib\x86_64-win64 mkdir lib\x86_64-win64
fpc wordpress.lpr @extra.cfg -o..\..\public_html\wordpress.bin %1
