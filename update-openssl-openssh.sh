#!/bin/bash
clear
export LANG="en_US.UTF-8"

#脚本变量
DATE=`date "+%Y%m%d"`
PREFIX="/usr/local"
DROPBEAR_VERSION="dropbear-2019.78"
OPENSSL_VERSION="openssl-1.1.1e"
OPENSSH_VERSION="openssh-8.2p1"
DROPBEAR_DOWNLOAD="https://matt.ucc.asn.au/dropbear/releases/$dropbear_version.tar.bz2"
OPENSSL_DOWNLOAD="https://www.openssl.org/source/$openssl_version.tar.gz" 
OPENSSH_DOWNLOAD="https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"
UNSUPPORTED_SYSTEM=`cat /etc/redhat-release | grep "release 3" | wc -l`

#检查用户
if [ $(id -u) != 0 ]; then
echo -e "当前登陆用户为普通用户，必须使用Root用户运行脚本，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#检查系统
if [ "$UNSUPPORTED_SYSTEM" == "1" ];then
clear
echo -e "脚本仅支持操作系统4.x-7.x版本，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#使用说明
echo -e "\033[33m快速编译安装OpenSSH\033[0m"
echo ""
echo "脚本仅适用于RHEL和CentOS操作系统，支持4.x-7.x版本"
echo "必须使用Root用户运行脚本，确保本机已配置好软件仓库"
echo "企业生产环境中建议先临时安装Dropbear，再安装OpenSSH"
echo "旧版本OpenSSH相关文件备份在/tmp/openssh_bak_$DATE"
echo ""

#安装Dropbear
function INSTALL_DROPBEAR() {

#安装依赖包
yum -y install gcc bzip2 wget make net-tools > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "安装软件依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装软件依赖包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#解压源码包
cd /tmp
wget --no-check-certificate $DROPBEAR_DOWNLOAD > /dev/null 2>&1
tar xjf $DROPBEAR_VERSION.tar.bz2 > /dev/null 2>&1
if [ -d /tmp/$DROPBEAR_VERSION ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#安装Dropbear
cd /tmp/$DROPBEAR_VERSION
./configure --disable-zlib > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装Dropbear失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#启动Dropbear
mkdir /etc/dropbear > /dev/null 2>&1
/usr/local/bin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
/usr/local/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbear -p 6666 > /dev/null 2>&1
netstat -lantp | grep -w "0.0.0.0:6666" > /dev/null 2>&1
if [ $? -eq 0 ];then
rm -rf /tmp/$DROPBEAR_VERSION*
iptables -I INPUT -p tcp --dport 6666 -m comment --comment "DropbearSSH" -j ACCEPT
echo -e "启动Dropbear服务成功" "\033[32m Success\033[0m"
echo ""
netstat -lantp | grep -w "0.0.0.0:6666" | awk '{print $7,$4}' | column -t
else
echo -e "启动Dropbear服务失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""
}

#卸载dropbear
function UNINSTALL_DROPBEAR() {

ps aux | grep "/usr/local/sbin/dropbear" | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
find /usr/local/ -name dropbear* | xargs rm -rf > /dev/null 2>&1
rm -rf /etc/dropbear > /dev/null 2>&1
rm -f /var/run/dropbear.pid > /dev/null 2>&1
ps aux | grep "/usr/local/sbin/dropbear" | grep -v grep > /dev/null 2>&1
if [ $? -ne 0 ];then
echo -e "卸载DropBear成功" "\033[32m Success\033[0m"
else
echo -e "卸载DropBear失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""
}

#升级OpenSSH
function OPENSSH() {

#创建备份目录
mkdir -p /tmp/openssh_bak_$DATE/etc/{init.d,pam.d} > /dev/null 2>&1
mkdir -p /tmp/openssh_bak_$DATE/usr/{bin,sbin,libexec} > /dev/null 2>&1

#安装依赖包
yum -y install vim gcc wget make pam-devel zlib-devel> /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "安装软件依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装软件依赖包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#解压源码包
cd /tmp
wget --no-check-certificate $OPENSSL_DOWNLOAD > /dev/null 2>&1
wget --no-check-certificate $OPENSSH_DOWNLOAD > /dev/null 2>&1
tar xzf $OPENSSL_VERSION.tar.gz
tar xzf $OPENSSH_VERSION.tar.gz
if [ -d /tmp/$OPENSSL_VERSION ] && [ -d /tmp/$OPENSSH_VERSION ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#备份旧版OpenSSH
mv /etc/ssh /tmp/openssh_bak_$DATE/etc > /dev/null 2>&1
mv /etc/init.d/sshd /tmp/openssh_bak_$DATE/etc/init.d > /dev/null 2>&1
mv /etc/pam.d/sshd /tmp/openssh_bak_$DATE/etc/pam.d > /dev/null 2>&1
mv /usr/bin/scp /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/sftp /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/ssh /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/ssh-add /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/ssh-agent /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/ssh-keygen /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/bin/ssh-keyscan /tmp/openssh_bak_$DATE/usr/bin > /dev/null 2>&1
mv /usr/sbin/sshd /tmp/openssh_bak_$DATE/usr/sbin > /dev/null 2>&1
mv /usr/libexec/sftp-server /tmp/openssh_bak_$DATE/usr/libexec > /dev/null 2>&1
mv /usr/libexec/ssh-keysign /tmp/openssh_bak_$DATE/usr/libexec > /dev/null 2>&1
mv /usr/libexec/ssh-pkcs11-helper /tmp/openssh_bak_$DATE/usr/libexec > /dev/null 2>&1
mv /usr/libexec/ssh-sk-helper /tmp/openssh_bak_$DATE/usr/libexec > /dev/null 2>&1

#安装OpenSSL
cd /tmp/$OPENSSL_VERSION
./config --prefix=$PREFIX/$OPENSSL_VERSION --openssldir=$PREFIX/$OPENSSL_VERSION/ssl -fPIC > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
echo "$PREFIX/$OPENSSL_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
else
echo -e "编译安装OpenSSL失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#安装OpenSSH
cd /tmp/$OPENSSH_VERSION
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-ssl-dir=$PREFIX/$OPENSSL_VERSION --with-zlib --with-pam --with-md5-passwords > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
cp -f /tmp/$OPENSSH_VERSION/contrib/redhat/sshd.init /etc/init.d/sshd
chmod +x /etc/init.d/sshd
chmod 600 /etc/ssh/*
chkconfig --add sshd
chkconfig sshd on
else
echo -e "编译安装OpenSSH失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#启动OpenSSH
service sshd restart > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "启动OpenSSH服务成功" "\033[32m Success\033[0m"
echo ""
ssh -V
else
echo -e "启动OpenSSH服务失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""

#删除源码包
rm -rf /tmp/$OPENSSL_VERSION*
rm -rf /tmp/$OPENSSH_VERSION*
}

#脚本菜单
echo -e "\033[36m1: 安装DropBear\033[0m"
echo ""
echo -e "\033[36m2: 卸载DropBear\033[0m"
echo ""
echo -e "\033[36m3: 安装OpenSSH\033[0m"
echo ""
echo -e "\033[36m4: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车开始执行脚本: " SELECT
if [ "$SELECT" == "1" ];then
clear
INSTALL_DROPBEAR
fi
if [ "$SELECT" == "2" ];then
clear
UNINSTALL_DROPBEAR
fi
if [ "$SELECT" == "3" ];then
clear
OPENSSH
fi
if [ "$SELECT" == "4" ];then
echo ""
exit
fi
