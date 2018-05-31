#!/bin/sh

# Textout via text2soled is duplicated with different paths becuase
#different linux systems exist

systemctl stop playground

function print2soled {
  Text=$1
  /nonlinear/text2soled/text2soled clear
  /nonlinear/text2soled clear
  /nonlinear/text2soled $Text 10 80
  /nonlinear/text2soled/text2soled $Text 10 80
}

/nonlinear/text2soled/text2soled 'Starting Update' 10 80
/nonlinear/text2soled 'Starting Update' 10 80

if [ -d "/update/system/" ]; then
  print2soled "TODO System Update Text"
  chmod +x /update/system/system_update.sh
  /bin/sh /update/system/system_update.sh
fi

if [ -d "/update/LPC/" ]; then
  print2soled "TODO LPC Update Text"
  chmod +x /update/LPC/lpc_update.sh
  /bin/sh /update/LPC/lpc_update.sh /update/LPC/blob.bin
fi

if [ -d "/update/EPC/" ]; then
  print2soled "TODO EPC Update Text"
  chmod +x /update/EPC/epc_update.sh
  /bin/sh /update/EPC/epc_update.sh
fi

if [ -d "/update/BBB/" ]; then
  print2soled "TODO BBB Update Text"
  chmod +x /update/BBB/bbb_update.sh
  /bin/sh /update/BBB/bbb_update.sh
fi

systemctl stop playground
print2soled "Done, please Restart!"
