#!/bin/bash

scripts_dir=/opt/zabbix-3.0.4/scripts
conf_dir=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf.d
agent_conf=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf
agent_cmd=/opt/zabbix-3.0.4/sbin/zabbix_agentd

if [[ ! -d $scripts_dir ]];then
	mkdir -p $scripts_dir
fi
rm -f $scripts_dir/discover_disk.pl 2>&1 > /dev/null
cat > $scripts_dir/discover_disk.pl  <<\EOF
#!/usr/bin/perl

sub get_vmname_by_id
  {
  $vmname=`cat /etc/qemu-server/$_[0].conf | grep name | cut -d \: -f 2`;
  $vmname =~ s/^\s+//; #remove leading spaces
  $vmname =~ s/\s+$//; #remove trailing spaces
  return $vmname
  }

$first = 1;
print "{\n";
print "\t\"data\":[\n\n";

for (`cat /proc/diskstats`)
  {
  ($major,$minor,$disk) = m/^\s*([0-9]+)\s+([0-9]+)\s+(\S+)\s.*$/;
  $dmnamefile = "/sys/dev/block/$major:$minor/dm/name";
  $vmid= "";
  $vmname = "";
  $dmname = $disk;
  $diskdev = "/dev/$disk";
  # DM name
  if (-e $dmnamefile) {
    $dmname = `cat $dmnamefile`;
    $dmname =~ s/\n$//; #remove trailing \n
    $diskdev = "/dev/mapper/$dmname";
    # VM name and ID
    if ($dmname =~ m/^.*--([0-9]+)--.*$/) {
      $vmid = $1;
      #$vmname = get_vmname_by_id($vmid);
      }
    }
  #print("$major $minor $disk $diskdev $dmname $vmid $vmname \n");

  print "\t,\n" if not $first;
  $first = 0;

  print "\t{\n";
  print "\t\t\"{#DISK}\":\"$disk\",\n";
  print "\t\t\"{#DISKDEV}\":\"$diskdev\",\n";
  print "\t\t\"{#DMNAME}\":\"$dmname\",\n";
  print "\t\t\"{#VMNAME}\":\"$vmname\",\n";
  print "\t\t\"{#VMID}\":\"$vmid\"\n";
  print "\t}\n";
  }

print "\n\t]\n";
print "}\n";
EOF
	chown zabbix:zabbix $scripts_dir/discover_disk.pl && chmod 755 $scripts_dir/discover_disk.pl 



if [[ `cat $agent_conf | grep -e "UnsafeUserParameters=1" | grep -v ^# | wc -l` -eq 1 ]];then
	echo ''
else
	echo 'UnsafeUserParameters=1' >> $agent_conf
fi

if [[ `cat $agent_conf | grep -e "Include" | grep -v ^#  | wc -l` -eq 1 ]];then
  rm -f $conf_dir/diskIO.conf 2>&1>/dev/null

	cat > $conf_dir/diskIO.conf <<\EOF
# diskio discovery
UserParameter=discovery.disks.iostats,/opt/zabbix-3.0.4/scripts/discover_disk.pl     #这里的地址看看是否需要修改！！

#读扇区的次数
UserParameter=custom.vfs.dev.read.sectors[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$6}' 

#写扇区次数
UserParameter=custom.vfs.dev.write.sectors[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$10}'  

#合并读完成次数
UserParameter=custom.vfs.dev.read.ops[*],cat /proc/diskstats | grep $1 | head -1 |awk '{print $$4}'

#合并写完成次数
UserParameter=custom.vfs.dev.write.ops[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$8}'

#读花费的毫秒数
UserParameter=custom.vfs.dev.read.ms[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$7}'

#写操作花费的毫秒数
UserParameter=custom.vfs.dev.write.ms[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$11}'
EOF

chown zabbix:zabbix $conf_dir/diskIO.conf

else
  echo 'Include=/opt/zabbix-agent-3.0.4/etc/zabbix_agentd.conf.d/*.conf' >> $agent_conf    ######################## 注意路径！##################
  rm -f $conf_dir/diskIO.conf 2>&1>/dev/null

  cat > $conf_dir/diskIO.conf <<\EOF
# diskio discovery
UserParameter=discovery.disks.iostats,/opt/zabbix-3.0.4/scripts/discover_disk.pl     #这里的地址看看是否需要修改！！
#读扇区的次数
UserParameter=custom.vfs.dev.read.sectors[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$6}' 

#写扇区次数
UserParameter=custom.vfs.dev.write.sectors[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$10}'  

#合并读完成次数
UserParameter=custom.vfs.dev.read.ops[*],cat /proc/diskstats | grep $1 | head -1 |awk '{print $$4}'

#合并写完成次数
UserParameter=custom.vfs.dev.write.ops[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$8}'

#读花费的毫秒数
UserParameter=custom.vfs.dev.read.ms[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$7}'

#写操作花费的毫秒数
UserParameter=custom.vfs.dev.write.ms[*],cat /proc/diskstats | grep $1 | head -1 | awk '{print $$11}'
EOF

fi

ps -ef | grep zabbix-agent | awk {'print $2'} | xargs kill 2>/dev/null
$agent_cmd 2>&1 >/dev/null
$agent_cmd 2>&1 >/dev/null

echo -e "\033[32m zabbix-agent restart to complete! \033[0m"
