#!/bin/bash

# writer:sunyuqing

#自动安装zabbix_agentd客户端!!!,需要以root身份运行！

#  >>>>>>>>>>>>>>>>>>>>>>>>>> 注意！>>>>>>>>>>>>>>>>>>>>>>>>>

# zabbix-3.0.4.tar.gz软件包一定要指定放在了哪里，不然会找不到源码包。

# zabbix_server 的ip地址一定要指定。

# src_dir时存放zabbix-3.0.4.tar.gz的目录

# src_tar_gz是zabbix-3.0.4.tar.gz的绝对路径！！

#  这里是zabbix_agentd安装到了/etc/zabbix-3.0.4/目录下，如有需要可以根据需求更改安装目录，建议默认为/etc/zabbix-3.0.4!

zabbix_server=172.16.1.253

src_dir="/sunyuqing"

src_tar_gz="/sunyuqing/zabbix-3.0.4.tar.gz"

#############################  开始安装zabbix_agentd服务   ##############################

sudo apt-get install gcc make -y 

cd $src_dir

tar zxf $src_tar_gz && cd zabbix-3.0.4 

./configure  --prefix=/opt/zabbix-3.0.4 --enable-agent --with-mysql && make install

if [[ $? = 0 ]];then
	echo -e "\033[32m zabbix-3.0.4安装成功，开始配置zabbix_agent.con文件....\033[0m"
else
	echo -e "\033[31m zabbix-3.0.4安装失败！！请检查源码包存放的地址！！！\033[0m"
	exit 1
fi

userdel -f zabbix > /dev/null
useradd -s /sbin/nologin -d /dev/null zabbix 


##################################  配置zabbix_agent.conf ##############################

echo -e  "\033[32m 正在配置zabbix_agent.conf......\033[0m"

#指定Server的ip地址
sed -i 's/Server=127.0.0.1/#Server=127.0.0.1/g' /opt/zabbix-3.0.4/etc/zabbix_agentd.conf

echo Server=$zabbix_server >> /opt/zabbix-3.0.4/etc/zabbix_agentd.conf

#指定ServerActive的ip地址
sed -i 's/ServerActive=127.0.0.1/#ServerActive=127.0.0.1/g' /opt/zabbix-3.0.4/etc/zabbix_agentd.conf

echo ServerActive=$zabbix_server >> /opt/zabbix-3.0.4/etc/zabbix_agentd.conf

#指定自己的主机名
sed -i 's/Hostname/#Hostname/g' /opt/zabbix-3.0.4/etc/zabbix_agentd.conf

echo Hostname=$HOSTNAME >> /opt/zabbix-3.0.4/etc/zabbix_agentd.conf


#包括代理的配置文件
echo Include=/opt/zabbix-3.0.4/etc/zabbix_agentd.conf.d/ >> /opt/zabbix-3.0.4/etc/zabbix_agentd.conf


#启用用户自定义的key
echo UnsafeUserParameters=1 >> /opt/zabbix-3.0.4/etc/zabbix_agentd.conf



##################################  配置zabbix_agentd ##############################

echo -e "\033[32m 正在配置zabbix_agentd为系统服务......\033[0m"

#cp $src_dir/zabbix-3.0.4/misc/init.d/fedora/core/zabbix_agentd /etc/rc.d/init.d/zabbix_agentd

#这里需要用\转义！！！！
#sed -i 's/BASEDIR=\/usr\/local/BASEDIR=\/opt\/zabbix-3.0.4/g' /etc/rc.d/init.d/zabbix_agentd

cat > /etc/init.d/zabbix_agentd  <<\EOF
#!/bin/bash
# chkconfig: 2345 55 25
# Description: Startup script for zabbix on Debian. Place in /etc/init.d and
# run 'update-rc.d -f nginx defaults', or use the appropriate command on your
# distro. For CentOS/Redhat run: 'chkconfig --add nginx'

### BEGIN INIT INFO
# Provides:          zabbix
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: starts the zabbix server
# Description:       starts zabbix using start-stop-daemon
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/opt/zabbix-3.0.4/sbin
NAME=zabbix_agentd
NGINX_BIN=/opt/zabbix-3.0.4/sbin/$NAME
CONFIGFILE=/opt/zabbix-3.0.4/etc/$NAME.conf
PIDFILE=/opt/$NAME.pid

case "$1" in
    start)
        echo -n "Starting $NAME... "

        if netstat -tnpl | grep -q $NAME;then
            echo "$NAME (pid `pidof $NAME`) already running."
            exit 1
        fi

        $NGINX_BIN -c $CONFIGFILE

        if [ "$?" != 0 ] ; then
            echo " failed"
            exit 1
        else
            echo " done"
        fi
        ;;

    stop)
        echo -n "Stoping $NAME... "

        if ! netstat -tnpl | grep -q $NAME; then
            echo "$NAME is not running."
            exit 1
        fi

#        $NGINX_BIN -s stop
	ps -ef | grep zabbix_agentd | awk {'print $2'} | xargs kill > /dev/null 

        if [ "$?" != 0 ] ; then
            echo " failed. Use force-quit"
            exit 1
        else
            echo " done"
        fi
        ;;

    status)
        if netstat -tnpl | grep -q $NAME; then
            PID=`pidof nginx`
            echo "$NAME (pid $PID) is running..."
        else
            echo "$NAME is stopped"
            exit 0
        fi
        ;;

    force-quit)
        echo -n "Terminating $NAME... "

        if ! netstat -tnpl | grep -q $NAME; then
            echo "$NAME is not running."
            exit 1
        fi

        kill `pidof $NAME`

        if [ "$?" != 0 ] ; then
            echo " failed"
            exit 1
        else
            echo " done"
        fi
        ;;

    restart)
        $0 stop
        sleep 1
        $0 start
        ;;

    reload)
        echo -n "Reload service $NAME... "

        if netstat -tnpl | grep -q $NAME; then
            $NGINX_BIN -s reload
            echo " done"
        else
            echo "$NAME is not running, can't reload."
            exit 1
        fi
        ;;

    configtest)
        echo -n "Test $NAME configure files... "

        $NGINX_BIN -t
        ;;

    *)
        echo "Usage: $0 {start|stop|force-quit|restart|reload|status|configtest}"
        exit 1
        ;;

esac
EOF

chmod +x /etc/init.d/zabbix_agentd

sudo apt-get install sysv-rc-conf -y 
sysv-rc-conf --level 2345 zabbix_agentd on

if [[ $? = 0 ]];then
        echo -e "\033[32m 服务zabbix_agentd已经添加到系统服务！\033[0m"
else
        echo -e  "\033[31m 添加zabbix_agentd为系统服务失败！！请检查！！！\033[0m"
        exit 1
fi

ln -s /opt/zabbix-3.0.4/sbin/* /usr/local/sbin/

ln -s /opt/zabbix-3.0.4/bin/* /usr/local/bin/


chown -R zabbix:zabbix /opt/zabbix-3.0.4/

/etc/init.d/zabbix_agentd restart || /etc/init.d/zabbix_agentd restart || sysv-rc-conf --level 2345 zabbix_agentd on  2>&1 >>/dev/null

sudo apt-get install net-tools -y 2>&1 >> /dev/null
netstat -anput | grep 10050

if [[ $? = 0 ]];then
        echo -e  "\033[32m 服务zabbix_agentd已经成功启动，10050端口已经成功监听\033[0m"
else
        echo -e "\033[31m 服务zabbix_agentd启动失败！！请检查！！！\033[0m"
        exit 1
fi

echo -e "\033[42;37m zabbix_agentd服务已经安装完毕，请在zabbix_server端用zabbix_get命令来测试是否能够获取信息！\033[0m"
ps -ef | grep zabbix
exit 1


##############################################   结束   #################################################
