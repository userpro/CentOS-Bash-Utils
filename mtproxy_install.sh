#!/usr/bin/env bash

# chmod 555 ./mtproxy.sh; ./mtproxy.sh
# Don't forget check ./MTProxy/objs/bin/everyday.sh permission.

# telegram MTProxy (CentOS 7)
localport=9090
netport=$(($RANDOM%2000+3000))
# 1.安装MTProxy
current_path=$(pwd)
yum -y install curl
yum -y install openssl-devel zlib-devel
yum -y groupinstall "Development tools"
git clone https://github.com/TelegramMessenger/MTProxy
cd MTProxy
make && cd objs/bin

# 2.设置MTProxy
curl -s https://core.telegram.org/getProxySecret -o proxy-secret
curl -s https://core.telegram.org/getProxyConfig -o proxy-multi.conf # 这个代理文件需要定期更新

# 2.1. 生成密钥
secret=$(head -c 16 /dev/urandom | xxd -ps)

# 2.2. 运行
# ./mtproto-proxy -u nobody -p 9090 -H 33332 -S <secret> --aes-pwd proxy-secret proxy-multi.conf -M 1
# 注释: -p <local port> -H <client port>

# 3.设置systemd
mtpfile=/etc/systemd/system/MTProxy.service
echo "[Unit]" > $mtpfile
echo "Description=MTProxy" >> $mtpfile
echo "After=network.target" >> $mtpfile
echo "" >> $mtpfile

echo "[Service]" >> $mtpfile
echo "Type=simple" >> $mtpfile
echo "WorkingDirectory=$current_path/MTProxy/objs/bin/" >> $mtpfile
echo "ExecStart=$current_path/MTProxy/objs/bin/mtproto-proxy -u nobody -p $localport -H $netport -S $secret --aes-pwd proxy-secret proxy-multi.conf -M 1" >> $mtpfile
echo "Restart=on-failure" >> $mtpfile
echo "" >> $mtpfile

echo "[Install]" >> $mtpfile
echo "WantedBy=multi-user.target" >> $mtpfile

systemctl daemon-reload
systemctl restart MTProxy.service
systemctl status MTProxy.service -l
systemctl enable MTProxy.service # 开机自启

# 4.定时更新
# vim everyday.sh
everyday="everyday.sh"
echo "#!/bin/sh" > $everyday
echo "/bin/curl -s https://core.telegram.org/getProxyConfig -o $current_path/MTProxy/objs/bin/proxy-multi.conf" >> $everyday
echo "/bin/systemctl restart MTProxy.service" >> $everyday
echo "/bin/echo \"date +%Y/%m/%d-%H:%M:%S\" > $current_path/MTProxy/objs/bin/log" >> $everyday
chmod 555 $everyday

cronfile=/var/spool/cron/root
echo "0 4 * * * $current_path/MTProxy/objs/bin/everyday.sh &> $current_path/MTProxy/objs/bin/errlog" > $cronfile
systemctl restart crond.service

# 5.打开端口
firewall-cmd --zone=public --add-port=$netport/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=public --list-ports

# 6.分享链接
netip=$(curl ifconfig.me)
echo "tg://proxy?server=$netip&port=$netport&secret=$secret"
