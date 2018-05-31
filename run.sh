#!/bin/sh

systemctl stop playground

/nonlinear/text2soled/text2soled 'Starting Update' 10 80
/nonlinear/text2soled 'Starting Update' 10 80

if [ -d "/update/system/" ]; then
  /nonlinear/text2soled/text2soled clear
  /nonlinear/text2soled clear
  /nonlinear/text2soled 'TODO TEXT' 10 80
  /nonlinear/text2soled/text2soled 'TODO TEXT' 10 80
  chmod +x /update/system/system_update.sh
  /bin/sh /update/system/system_update.sh
fi

if [ -d "/update/LPC/" ]; then
  /nonlinear/text2soled/text2soled clear
  /nonlinear/text2soled clear
  /nonlinear/text2soled 'TODO TEXT' 10 80
  /nonlinear/text2soled/text2soled 'TODO TEXT' 10 80
  chmod +x /update/LPC/lpc_update.sh
  /bin/sh /update/LPC/lpc_update.sh /update/LPC/blob.bin
fi

if [ -d "/update/EPC/" ]; then
  /nonlinear/text2soled/text2soled clear
  /nonlinear/text2soled clear
  /nonlinear/text2soled 'TODO TEXT' 10 80
  /nonlinear/text2soled/text2soled 'TODO TEXT' 10 80
  chmod +x /update/EPC/epc_update.sh
  /bin/sh /update/EPC/epc_update.sh
fi

if [ -d "/update/BBB/" ]; then
  /nonlinear/text2soled/text2soled clear
  /nonlinear/text2soled clear
  /nonlinear/text2soled 'TODO TEXT' 10 80
  /nonlinear/text2soled/text2soled 'TODO TEXT' 10 80
  chmod +x /update/BBB/bbb_update.sh
  /bin/sh /update/BBB/bbb_update.sh
fi

systemctl stop playground
/nonlinear/text2soled/text2soled clear
/nonlinear/text2soled clear
/nonlinear/text2soled/text2soled 'Please restart!' 10 80
/nonlinear/text2soled 'Please restart!' 10 80
