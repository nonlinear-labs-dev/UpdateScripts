#!/bin/sh
# system_linux

# get time from the NonLinux ePC and set it on the BBB
# Author:	Anton Schmied
# Version:	1.0
# Date:		16.10.2019

getEPCtime(){
        /nonlinear/utilities/sshpass -p 'sscl' ssh sscl@192.168.10.10 'date "+%F %T"'
}

date "+%F %T" -s "$(getEPCtime)"
