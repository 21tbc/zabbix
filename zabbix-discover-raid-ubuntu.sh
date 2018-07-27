#!/bin/bash
#The use of the template is used to implement raid disk auto-discovery and bad channel monitoring alarm
#writer:sunyuqing
#date:2017-05-09

# remote_host=120.132.46.36
# remote_user=root
# remote_port=2222
# remote_passwd=server.123

scripts_dir=/opt/zabbix-3.0.4/scripts
conf_dir=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf.d
agent_conf=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf
agent_cmd=/opt/zabbix-3.0.4/sbin/zabbix_agentd

if [[ ! -d $scripts_dir ]];then
	mkdir -p $scripts_dir
fi

sudo /usr/sbin/megacli -AdpAllInfo -aALL -NoLog > /tmp/tmp.txt

if [[ `wc /tmp/tmp.txt | awk {'print $1'}` -gt 8 ]];then

#################### Write the automatic discovery raid script  ############################
	rm -rf $scripts_dir/raid_discover.sh 2>&1 > /dev/null
	cat > $scripts_dir/raid_discover.sh  <<\EOF
#!/bin/bash
###raid_id_discover.sh
###wuhf###
num=0
RAID_stats() {
DISK=($(sudo /usr/sbin/megacli -pdlist -aALL | grep "Slot Number" | awk -F":" '{print $2}'))
printf '{\n\t"data":[\n'
for key in ${DISK[@]};do
        if [[ "${#DISK[@]}" -gt "$num" && "$num" -ne "$((${#DISK[@]}-1))" ]];then
        printf "\t\t{\"{#RAID_ID}\":\"$key\"},\n"
        let "num++"
        elif [[ "$((${#DISK[@]}-1))" -eq "$num" ]];then
        printf "\t\t{\"{#RAID_ID}\":\"$key\"}\n"
        fi
done
printf '\t]\n}\n'
}
RAID_stats
EOF
	echo -e "\033[32m $scripts_dir/raid_discover.sh Write to complete! \033[0m"

	cd $scripts_dir && chmod 755 raid_discover.sh && chown zabbix:zabbix raid_discover.sh 

#################### Write the zabbix monitoring item configuration  ############################
	rm -rf $conf_dir/raid.conf 2>&1 >/dev/null
	cat > $conf_dir/raid.conf  <<\EOF	
UserParameter=raid_discover,bash /opt/zabbix-3.0.4/scripts/raid_discover.sh

#raid已被降级！
UserParameter=raid_degraded,sudo /usr/sbin/megacli -AdpAllInfo -aALL -NoLog | grep "Degraded" |awk '{print $NF}'

#磁盘出现故障！
UserParameter=raid_failed_disks,sudo /usr/sbin/megacli -AdpAllInfo -aALL -NoLog | grep "Failed Disks" |awk '{print $NF}'

#磁盘有坏道！
UserParameter=raid_MEC[*],sudo /usr/sbin/megacli -PDList -aAll -NoLog | grep -A 8 "Slot Number: $1" | grep "Media Error Count" | awk '{print $NF}'

#磁盘有逻辑错误！
UserParameter=raid_OEC[*],sudo /usr/sbin/megacli -PDList -aAll -NoLog | grep -A 8 "Slot Number: $1" | grep "Other Error Count" | awk '{print $NF}'

#预计将要坏的磁盘！
UserParameter=raid_Predictive[*],sudo /usr/sbin/megacli -pdlist -aALL  | grep -A 8 "Slot Number: $1" | grep "Predictive Failure Count" | awk '{print $NF}'

#磁盘自检健康状态，NO为健康，YES为有问题！
UserParameter=raid_SMART[*],sudo /usr/sbin/megacli -pdlist -aALL  | grep -A 45 "Slot Number: $1" | grep "S.M.A.R.T" | awk '{print $NF}'
EOF

	echo -e "\033[32m $conf_dir/raid.conf Write to complete! \033[0m"


	if [[ `cat $agent_conf | grep -e "Include" | grep -v ^#  | wc -l` -eq 1 ]];then
		echo ''
	else
 		echo 'Include=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf.d/*.conf' >> $agent_conf    ######################## 注意路径！##################
	fi

	if [[ `cat $agent_conf | grep -e "UnsafeUserParameters=1" |grep -v ^# | wc -l` -eq 1 ]];then
		echo ''
	else
		echo 'UnsafeUserParameters=1' >> $agent_conf
	fi

	chown zabbix:zabbix $conf_dir/raid.conf 
	if [[ `cat /etc/sudoers | grep -e "zabbix ALL=(root) NOPASSWD:ALL" | grep -v ^#  | wc -l` -eq 1 ]];then
		echo ''
	else
		echo "zabbix ALL=(root) NOPASSWD:ALL" >> /etc/sudoers
	fi

	if [[ `cat /etc/sudoers | grep -e "Defaults.*.requiretty" | grep -v ^#  | wc -l` -eq 0 ]];then
		echo ''
	else
		sed -i 's/^Defaults.*.requiretty/#Defaults    requiretty/' /etc/sudoers
	fi
	
#################### Restart zabbix and record the result  ############################

ps -ef | grep zabbix-agent | awk {'print $2'} | xargs kill 2>/dev/null
$agent_cmd 2>&1 >/dev/null

echo -e "\033[32m zabbix-agent restart to complete! \033[0m"

# yum -y install sshpass 2>&1 >/dev/null
# sshpass -p $remote_passwd ssh -t -p $remote_port $remote_user@$remote_host 'echo `who am i` install Success! >> /tmp/zabbix-discover-raid+diskIO.log'
# echo -e "\033[42;37m $HOSTNAME install Success!  \033[0m"

else
	# yum -y install sshpass 2>&1 >/dev/null
	# sshpass -p $remote_passwd ssh -t -p $remote_port $remote_user@$remote_host 'echo `who am i` install faied! >> /tmp/zabbix-discover-raid+diskIO.log'
	# echo -e "\033[41;37m $HOSTNAME 不支持此操作，正在退出…… \033[0m"
	ps -ef | grep zabbix-agent | awk {'print $2'} | xargs kill 2>/dev/null
	$agent_cmd 2>&1 >/dev/null

	echo -e "\033[32m zabbix-agent restart to complete! \033[0m"
	exit

fi
#END
