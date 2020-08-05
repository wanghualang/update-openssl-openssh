#!/bin/bash
clear
export LANG="en_US.UTF-8"

#脚本变量
DATE=`date "+%Y%m%d"`
PREFIX="/usr/local"
PERL_VERSION="5.32.0"
OPENSSL_VERSION="openssl-1.1.1g"
OPENSSH_VERSION="openssh-8.3p1"
DROPBEAR_VERSION="dropbear-2020.80"
PERL_DOWNLOAD="https://www.cpan.org/src/5.0/perl-$PERL_VERSION.tar.gz"
OPENSSL_DOWNLOAD="https://www.openssl.org/source/$OPENSSL_VERSION.tar.gz"
OPENSSH_DOWNLOAD="https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/$OPENSSH_VERSION.tar.gz"
DROPBEAR_DOWNLOAD="https://matt.ucc.asn.au/dropbear/releases/$DROPBEAR_VERSION.tar.bz2"
DROPBEAR_PORT="6666"
OPENSSH_RPM_INSTALLED=$(rpm -qa | grep ^openssh | wc -l)
SYSTEM_VERSION=$(cat /etc/redhat-release | sed -r 's/.* ([0-9]+)\..*/\1/')

#检查用户
if [ $(id -u) != 0 ]; then
echo -e "必须使用Root用户运行脚本" "\033[31m Failure\033[0m"
echo ""
exit
fi

#检查系统
if [ ! -e /etc/redhat-release ] || [ "$SYSTEM_VERSION" == "3" ] || [ "$SYSTEM_VERSION" == "4" ];then
clear
echo -e "脚本仅适用于RHEL和CentOS操作系统5.x-8.x版本" "\033[31m Failure\033[0m"
echo ""
exit
fi

#使用说明
echo -e "\033[33m一键升级OpenSSH\033[0m"
echo ""
echo "脚本仅适用于RHEL和CentOS操作系统5.X-8.X版本"
echo "建议先临时安装DropbearSSH，再开始升级OpenSSH"
echo "旧版本OpenSSH备份在/tmp/openssh_bak_$DATE"
echo ""

#安装Dropbear
function INSTALL_DROPBEAR() {
echo -e "\033[33m正在安装DropBearSSH\033[0m"
echo ""

#安装依赖包
yum -y install gcc bzip2 wget make > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "安装依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装依赖包失败" "\033[31m Failure\033[0m"
echo ""
exit
fi
echo ""

#解压源码包
cd /tmp
wget --no-check-certificate $DROPBEAR_DOWNLOAD > /dev/null 2>&1
tar xjf $DROPBEAR_VERSION.tar.bz2 > /dev/null 2>&1
if [ -d /tmp/$DROPBEAR_VERSION ];then
echo -e "解压源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压源码包失败" "\033[31m Failure\033[0m"
echo ""
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
echo -e "编译安装失败" "\033[31m Failure\033[0m"
echo ""
exit
fi

#启动Dropbear
mkdir /etc/dropbear > /dev/null 2>&1
/usr/local/bin/dropbearkey -t rsa -s 2048 -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbear -p $DROPBEAR_PORT > /dev/null 2>&1
ps aux | grep dropbear | grep -v grep > /dev/null 2>&1
if [ $? -eq 0 ];then
rm -rf /tmp/$DROPBEAR_VERSION*
echo -e "启动服务端成功" "\033[32m Success\033[0m"
else
echo -e "启动服务端失败" "\033[31m Failure\033[0m"
exit
fi
echo ""
}

#卸载Dropbear
function UNINSTALL_DROPBEAR() {
echo -e "\033[33m正在卸载DropBearSSH\033[0m"
echo ""
ps aux | grep dropbear | grep -v grep | awk '{print $2}' | xargs kill -9 > /dev/null 2>&1
rm -rf /etc/dropbear
rm -f /var/run/dropbear.pid
rm -f /usr/local/sbin/dropbear
rm -f /usr/local/bin/dropbearkey
rm -f /usr/local/bin/dropbearconvert
rm -f /usr/local/share/man/man8/dropbear*
rm -f /usr/local/share/man/man1/dropbear*
ps aux | grep dropbear | grep -v grep > /dev/null 2>&1
if [ $? -ne 0 ];then
echo -e "卸载服务端成功" "\033[32m Success\033[0m"
else
echo -e "卸载服务端失败" "\033[31m Failure\033[0m"
exit
fi
echo ""
}

#升级OpenSSH
function INSTALL_OPENSSH() {
echo -e "\033[33m正在升级OpenSSH\033[0m"
echo ""

#安装依赖包
yum -y install gcc wget make perl-devel pam-devel zlib-devel > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "安装依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装依赖包失败" "\033[31m Failure\033[0m"
echo ""
exit
fi
echo ""

#解压源码包
cd /tmp
wget --no-check-certificate $OPENSSL_DOWNLOAD > /dev/null 2>&1
wget --no-check-certificate $OPENSSH_DOWNLOAD > /dev/null 2>&1
tar xzf $OPENSSL_VERSION.tar.gz > /dev/null 2>&1
tar xzf $OPENSSH_VERSION.tar.gz > /dev/null 2>&1
if [ -d /tmp/$OPENSSL_VERSION ] && [ -d /tmp/$OPENSSH_VERSION ];then
echo -e "解压源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压源码包失败" "\033[31m Failure\033[0m"
echo ""
exit
fi
echo ""

#创建备份目录
mkdir -p /tmp/openssh_bak_$DATE/etc/{init.d,pam.d,ssh}
mkdir -p /tmp/openssh_bak_$DATE/usr/{bin,sbin,libexec}
mkdir /tmp/openssh_bak_$DATE/usr/libexec/openssh

#备份旧程序
cp -af /etc/ssh/* /tmp/openssh_bak_$DATE/etc/ssh/ > /dev/null 2>&1
cp -af /etc/init.d/sshd /tmp/openssh_bak_$DATE/etc/init.d/ > /dev/null 2>&1
cp -af /etc/pam.d/sshd /tmp/openssh_bak_$DATE/etc/pam.d/ > /dev/null 2>&1
cp -af /usr/bin/scp /tmp/openssh_bak_$DATE/usr/bin/ > /dev/null 2>&1
cp -af /usr/bin/sftp /tmp/openssh_bak_$DATE/usr/bin/ > /dev/null 2>&1
cp -af /usr/bin/ssh* /tmp/openssh_bak_$DATE/usr/bin/ > /dev/null 2>&1
cp -af /usr/bin/slogin /tmp/openssh_bak_$DATE/usr/bin/ > /dev/null 2>&1
cp -af /usr/sbin/sshd* /tmp/openssh_bak_$DATE/usr/sbin/ > /dev/null 2>&1
cp -af /usr/libexec/ssh* /tmp/openssh_bak_$DATE/usr/libexec/ > /dev/null 2>&1
cp -af /usr/libexec/sftp* /tmp/openssh_bak_$DATE/usr/libexec/ > /dev/null 2>&1
cp -af /usr/libexec/openssh/* /tmp/openssh_bak_$DATE/usr/libexec/openssh/ > /dev/null 2>&1

#卸载旧程序
if [ "$OPENSSH_RPM_INSTALLED" == "0" ];then
rm -f /etc/ssh/*
rm -f /etc/init.d/sshd
rm -f /etc/pam.d/sshd
rm -f /usr/bin/scp
rm -f /usr/bin/sftp
rm -f /usr/bin/ssh
rm -f /usr/bin/slogin
rm -f /usr/bin/ssh-add
rm -f /usr/bin/ssh-agent
rm -f /usr/bin/ssh-keygen
rm -f /usr/bin/ssh-copy-id
rm -f /usr/bin/ssh-keyscan
rm -f /usr/sbin/sshd
rm -f /usr/sbin/sshd-keygen
rm -f /usr/libexec/openssh/*
rm -f /usr/libexec/sftp-server
rm -f /usr/libexec/ssh-keysign
rm -f /usr/libexec/ssh-sk-helper
rm -f /usr/libexec/ssh-pkcs11-helper
else
rpm -e --nodeps `rpm -qa | grep ^openssh` > /dev/null 2>&1
rm -f /etc/ssh/*
fi

#升级Perl
if [ "$SYSTEM_VERSION" == "5" ];then
cd /tmp
wget --no-check-certificate $PERL_DOWNLOAD > /dev/null 2>&1
tar xzf perl-$PERL_VERSION.tar.gz > /dev/null 2>&1
cd perl-$PERL_VERSION
./Configure -des -Dprefix=/usr/local/perl-$PERL_VERSION > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1
mv /usr/bin/perl /tmp/openssh_bak_$DATE/usr/bin/ > /dev/null 2>&1
ln -sf /usr/local/perl-$PERL_VERSION/bin/perl /usr/bin/perl > /dev/null 2>&1
fi

#安装OpenSSL
cd /tmp/$OPENSSL_VERSION
./config --prefix=$PREFIX/$OPENSSL_VERSION --openssldir=$PREFIX/$OPENSSL_VERSION/ssl -fPIC > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
echo "$PREFIX/$OPENSSL_VERSION/lib" >> /etc/ld.so.conf
ldconfig > /dev/null 2>&1
else
echo -e "编译安装OpenSSL失败" "\033[31m Failure\033[0m"
echo ""
exit
fi

#安装OpenSSH
cd /tmp/$OPENSSH_VERSION
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-ssl-dir=$PREFIX/$OPENSSL_VERSION --with-zlib --with-pam --with-md5-passwords > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config > /dev/null 2>&1
cp -af /tmp/$OPENSSH_VERSION/contrib/redhat/sshd.init /etc/init.d/sshd
chmod +x /etc/init.d/sshd
chmod 600 /etc/ssh/*
chkconfig --add sshd
chkconfig sshd on
else
echo -e "编译安装OpenSSH失败" "\033[31m Failure\033[0m"
echo ""
exit
fi

#启动OpenSSH
service sshd start > /dev/null 2>&1
if [ $? -eq 0 ];then
echo -e "启动服务端成功" "\033[32m Success\033[0m"
echo ""
ssh -V
else
echo -e "启动服务端失败" "\033[31m Failure\033[0m"
exit
fi
echo ""

#删除源码包
rm -rf /tmp/$OPENSSL_VERSION*
rm -rf /tmp/$OPENSSH_VERSION*
rm -rf /tmp/perl-$PERL_VERSION*
}

#脚本菜单
echo -e "\033[36m1: 安装DropBearSSH\033[0m"
echo ""
echo -e "\033[36m2: 卸载DropBearSSH\033[0m"
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
INSTALL_OPENSSH
fi
if [ "$SELECT" == "4" ];then
echo ""
exit
fi
