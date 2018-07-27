#!/bin/bash
# File Name: chkdisk.sh
# Description: Get the disk infomations for zabbix.
# Date: 2017-10-23

#MEGACLI_EXEC="/opt/MegaRAID/MegaCli/MegaCli64"   #use centos
MEGACLI_EXEC="/usr/sbin/megacli"     #use ubuntu

LIST_DISK_OPT="-PDList -aALL -NoLog"

#GET_DISK_NUM_OPT="-PDGetNum -aALL -NOLOG"

SLOT_NUMBER="Slot Number"
DEVICE_ID="Device Id"
WWN="WWN"
MEC="Media Error Count"
OEC="Other Error Count"
PRC="Predictive Failure Count"
PD_TYPE="PD Type"
RAW_SIZE="Raw Size"
FIRMWARE_STATE="Firmware state"
INQUIRY_DATA="Inquiry Data"


$MEGACLI_EXEC $LIST_DISK_OPT | egrep "$SLOT_NUMBER|$DEVICE_ID|$WWN|$MEC|$OEC|$PRC|$PD_TYPE|$RAW_SIZE|$FIRMWARE_STATE|$INQUIRY_DATA" > chkdisk_out
split -l 10 -d chkdisk_out slotnum

for i in `ls slotnum*`; do
    slot_number=`grep "$SLOT_NUMBER" $i | awk -F ': ' '{print $2}'`
    mec=`grep "$MEC" $i | awk -F ': ' '{print $2}'`
    prc=`grep "$PRC" $i | awk -F ': ' '{print $2}'`
    firmware_state=`grep "$FIRMWARE_STATE" $i | awk -F ': ' '{print $2}'`
    echo "$SLOT_NUMBER: $slot_number, $MEC: $mec, $PRC: $prc, $FIRMWARE_STATE: $firmware_state"
done