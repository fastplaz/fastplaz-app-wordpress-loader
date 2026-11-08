#!/bin/bash
# usage: ./compile.sh [extra fpc options, e.g. -Tlinux]
mkdir -p lib/$(fpc -iTP)-$(fpc -iTO)
fpc wordpress.lpr @extra.cfg -o../../public_html/wordpress.bin $1
