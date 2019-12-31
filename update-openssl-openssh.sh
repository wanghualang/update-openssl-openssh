#!/bin/bash
clear
export LANG="en_US.UTF-8"

#脚本变量
DATE=`date "+%Y%m%d"`
PREFIX="/usr/local"
DROPBEAR_VERSION="dropbear-2019.78"
ZLIB_VERSION="zlib-1.2.11"
OPENSSL_VERSION="openssl-1.0.2u"
OPENSSH_VERSION="openssh-8.1p1"
DROPBEAR_DOWNLOAD="https://matt.ucc.asn.au/dropbear/releases/$dropbear_version.tar.bz2"
ZLIB_DOWNLOAD="http://zlib.net/$zlib_version.tar.gz" 
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
echo -e "\033[33m软件升级\033[0m"
#echo ""
#echo "脚本仅适用于RHEL和CentOS操作系统，支持4.x-7.x版本"
#echo "必须使用Root用户运行脚本，确保本机已配置好软件仓库"
#echo "企业生产环境中建议先临时安装Dropbear，再升级OpenSSH"
#echo "旧版本OpenSSH文件备份在/tmp/backup_$DATE/openssh"
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

#下载源码包
cd /tmp
wget --no-check-certificate $DROPBEAR_DOWNLOAD > /dev/null 2>&1
if [ -e /tmp/$DROPBEAR_VERSION.tar.bz2 ];then
echo -e "下载软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "下载软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#解压源码包
cd /tmp
tar xjf $DROPBEAR_VERSION.tar.bz2
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
echo -e "启动Dropbear服务成功" "\033[32m Success\033[0m"
echo ""
echo -e "服务监听本地端口6666" "\033[33m Warnning\033[0m"
else
echo -e "启动Dropbear服务失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""

#删除源码包
rm -rf /tmp/$DROPBEAR_VERSION*
}

#卸载dropbear
function UNINSTALL_DROPBEAR() {

ps aux | grep dropbear | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
find /usr/local/ -name dropbear* | xargs rm -rf > /dev/null 2>&1
rm -rf /etc/dropbear > /dev/null 2>&1
rm -rf /var/run/dropbear.pid > /dev/null 2>&1
ps aux | grep -w "/usr/local/sbin/dropbear" | grep -v grep > /dev/null 2>&1
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
mkdir -p /tmp/backup_$DATE/openssh > /dev/null 2>&1
mkdir -p /tmp/backup_$DATE/openssh/usr/{bin,sbin} > /dev/null 2>&1
mkdir -p /tmp/backup_$DATE/openssh/etc/{init.d,pam.d,ssh} > /dev/null 2>&1
mkdir -p /tmp/backup_$DATE/openssh/usr/libexec/openssh > /dev/null 2>&1
mkdir -p /tmp/backup_$DATE/openssh/usr/share/man/{man1,man8} > /dev/null 2>&1

#安装依赖包
yum -y install vim gcc wget make pam-devel > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "安装软件依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装软件依赖包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#下载源码包
cd /tmp
wget --no-check-certificate $ZLIB_DOWNLOAD > /dev/null 2>&1
wget --no-check-certificate $OPENSSL_DOWNLOAD > /dev/null 2>&1
wget --no-check-certificate $OPENSSH_DOWNLOAD > /dev/null 2>&1
if [ -e /tmp/$ZLIB_VERSION.tar.gz ] && [ -e /tmp/$OPENSSL_VERSION.tar.gz ] && [ -e /tmp/$OPENSSH_VERSION.tar.gz ];then
echo -e "下载软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "下载软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#解压源码包
cd /tmp
tar xzf $ZLIB_VERSION.tar.gz
tar xzf $OPENSSL_VERSION.tar.gz
tar xzf $OPENSSH_VERSION.tar.gz
if [ -d /tmp/$ZLIB_VERSION ] && [ -d /tmp/$OPENSSL_VERSION ] && [ -d /tmp/$OPENSSH_VERSION ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#安装Zlib
cd /tmp/$ZLIB_VERSION
./configure --prefix=$PREFIX/$ZLIB_VERSION > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装压缩库失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

if [ -e $PREFIX/$ZLIB_VERSION/lib/libz.so ];then
echo "$PREFIX/$ZLIB_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
echo -e "编译安装压缩库成功" "\033[32m Success\033[0m"
else
echo -e "编译安装压缩库失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#备份旧版OpenSSH
rpm -qa | grep -w "openssh-server" > /dev/null 2>&1
if [ $? -eq 0 ];then
cp /usr/bin/ssh* /tmp/backup_$DATE/openssh/usr/bin > /dev/null 2>&1
cp /usr/sbin/sshd /tmp/backup_$DATE/openssh/usr/sbin > /dev/null 2>&1
cp /etc/init.d/sshd /tmp/backup_$DATE/openssh/etc/init.d > /dev/null 2>&1
cp /etc/pam.d/sshd /tmp/backup_$DATE/openssh/etc/pam.d > /dev/null 2>&1
cp /etc/ssh/ssh* /tmp/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
cp /etc/ssh/sshd_config /tmp/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
cp /usr/share/man/man1/ssh* /tmp/backup_$DATE/openssh/usr/share/man/man1 > /dev/null 2>&1
cp /usr/share/man/man8/ssh* /tmp/backup_$DATE/openssh/usr/share/man/man8 > /dev/null 2>&1
cp /usr/libexec/openssh/ssh* /tmp/backup_$DATE/openssh/usr/libexec/openssh > /dev/null 2>&1
rpm -e --nodeps openssh-clients openssh-server openssh > /dev/null 2>&1
else
mv /usr/bin/ssh* /tmp/backup_$DATE/openssh/usr/bin > /dev/null 2>&1
mv /usr/sbin/sshd /tmp/backup_$DATE/openssh/usr/sbin > /dev/null 2>&1
mv /etc/init.d/sshd /tmp/backup_$DATE/openssh/etc/init.d > /dev/null 2>&1
mv /etc/pam.d/sshd /tmp/backup_$DATE/openssh/etc/pam.d > /dev/null 2>&1
mv /etc/ssh/ssh* /tmp/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
mv /etc/ssh/sshd_config /tmp/backup_$DATE/openssh/etc/ssh > /dev/null 2>&1
mv /usr/share/man/man1/ssh* /tmp/backup_$DATE/openssh/usr/share/man/man1 > /dev/null 2>&1
mv /usr/share/man/man8/ssh* /tmp/backup_$DATE/openssh/usr/share/man/man8 > /dev/null 2>&1
mv /usr/libexec/ssh* /tmp/backup_$DATE/openssh/usr/libexec > /dev/null 2>&1
fi

#安装OpenSSL
cd /tmp/$OPENSSL_VERSION
./config --prefix=$PREFIX/$OPENSSL_VERSION --openssldir=$PREFIX/$OPENSSL_VERSION/ssl -fPIC > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装OpenSSL失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

if [ -e $PREFIX/$OPENSSL_VERSION/bin/openssl ];then
echo "$PREFIX/$OPENSSL_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
echo -e "编译安装OpenSSL成功" "\033[32m Success\033[0m"
fi
echo ""

#安装OpenSSH
cd /tmp/$OPENSSH_VERSION
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-ssl-dir=$PREFIX/$OPENSSL_VERSION --with-zlib=$PREFIX/$ZLIB_VERSION --with-pam --with-md5-passwords > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装OpenSSH失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

if [ -e /usr/sbin/sshd ];then
echo -e "编译安装OpenSSH成功" "\033[32m Success\033[0m"
fi
echo ""

#配置OpenSSH服务端（允许root登陆）
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

#启动OpenSSH
cp -rf /tmp/$OPENSSH_VERSION/contrib/redhat/sshd.init /etc/init.d/sshd
cp -rf /tmp/$OPENSSH_VERSION/contrib/redhat/sshd.pam /etc/pam.d/sshd
chmod +x /etc/init.d/sshd
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_dsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key
chkconfig --add sshd
chkconfig sshd on

service sshd start > /dev/null 2>&1
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
rm -rf /tmp/$ZLIB_VERSION*
}

#脚本菜单
echo -e "\033[36m1: 安装DropBear\033[0m"
echo ""
echo -e "\033[36m2: 卸载DropBear\033[0m"
echo ""
echo -e "\033[36m3: 升级OpenSSH\033[0m"
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
