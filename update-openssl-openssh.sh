#!/bin/bash
clear

#脚本变量
date=`date "+%Y%m%d"`
system_version=`cat /etc/redhat-release`
prefix="/usr/local"
zlib_version="zlib-1.2.11"
dropbear_version="dropbear-2018.76"
openssl_version="openssl-1.0.2r"
openssh_version="openssh-7.9p1"
zlib_download="http://zlib.net/$zlib_version.tar.gz"
dropbear_download="https://matt.ucc.asn.au/dropbear/releases/$dropbear_version.tar.bz2"
openssl_download="https://www.openssl.org/source/$openssl_version.tar.gz"
openssh_download="https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"
rhel3_version=`cat /etc/redhat-release | grep "release 3" | wc -l`
rhel4_version=`cat /etc/redhat-release | grep "release 4" | wc -l`
rhel5_version=`cat /etc/redhat-release | grep "release 5" | wc -l`
rhel6_version=`cat /etc/redhat-release | grep "release 6" | wc -l`
rhel7_version=`cat /etc/redhat-release | grep "release 7" | wc -l`
gcc_intall_status=`rpm -qa | grep -w gcc | wc -l`
pam_devel_intall_status=`rpm -qa | grep -w "pam-devel" | wc -l`
zlib_devel_intall_status=`rpm -qa | grep -w "zlib-devel" | wc -l`
bzip2_intall_status=`rpm -qa | grep -w "bzip2" | wc -l`
wget_intall_status=`rpm -qa | grep -w "wget" | wc -l`
make_intall_status=`rpm -qa | grep -w "make" | wc -l`
openssh_rpm_status=`rpm -qa | grep -w "openssh-server" | wc -l`
telnet_rpm_status=`rpm -qa | grep -w "telnet-server" | wc -l`
telnet_running_status=`ps aux | grep -w "xinetd" | grep -v grep | wc -l`
dropbear_running_status=`ps aux | grep -w "/usr/local/sbin/dropbear" | grep -v grep | wc -l`
openssh_running_status=`ps aux | grep -w "/usr/sbin/sshd" | grep -v grep | wc -l`

#检查用户
if [ $(id -u) != 0 ]; then
echo -e "当前登陆用户为普通用户，必须使用Root用户运行脚本，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#检查系统
if [ "$rhel3_version" == "1" ];then
clear
echo -e "脚本仅支持操作系统4.x-7.x版本，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#使用说明
echo -e "\033[33m软件升级 · 脚本说明\033[0m"
echo ""
echo "A.脚本仅适用于RHEL和CentOS操作系统，支持4.x-7.x版本；"
echo "B.必须使用Root用户运行脚本，确保本机已配置好软件仓库；"
echo "C.4.x - 5.x操作系统会临时安装Telnet，服务端口为23；"
echo "D.6.x - 7.x操作系统会临时安装DropBear，服务端口为6666；"
echo "E.旧版本OpenSSH相关文件备份在/tmp/backup_$date/openssh。"
echo ""

echo "本机操作系统：$system_version"
echo ""

#停用SElinux
setenforce 0 > /dev/null 2>&1

#停用防火墙
if [ "$rhel7_version" == "1" ];then
systemctl stop firewalld > /dev/null 2>&1
else
service iptables stop > /dev/null 2>&1
service ip6tables stop > /dev/null 2>&1
fi

#升级软件
function update() {

#创建备份目录
mkdir -p /tmp/backup_$date/openssh
mkdir -p /tmp/backup_$date/openssh/usr/{bin,sbin}
mkdir -p /tmp/backup_$date/openssh/etc/{init.d,pam.d,ssh}
mkdir -p /tmp/backup_$date/openssh/usr/libexec/openssh
mkdir -p /tmp/backup_$date/openssh/usr/share/man/{man1,man8}

#安装基础包
yum -y install gcc pam-devel bzip2 wget make > /dev/null 2>&1
cd /tmp
wget --no-check-certificate $zlib_download > /dev/null 2>&1
tar xzf $zlib_version.tar.gz
cd /tmp/$zlib_version
./configure --prefix=$prefix/$zlib_version > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1
echo "$prefix/$zlib_version/lib" >> /etc/ld.so.conf
ldconfig
if [ "$gcc_intall_status" != "0" ] && [ "$pam_devel_intall_status" != "0" ] && [ "$bzip2_intall_status" != "0" ] && [ "$wget_intall_status" != "0" ] && [ "$make_intall_status" != "0" ] && [ -e $prefix/$zlib_version/lib/libz.so ];then
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
wget --no-check-certificate $dropbear_download > /dev/null 2>&1
wget --no-check-certificate $openssl_download > /dev/null 2>&1
wget --no-check-certificate $openssh_download > /dev/null 2>&1
tar xjf $dropbear_version.tar.bz2
tar xzf $openssh_version.tar.gz
tar xzf $openssl_version.tar.gz
if [ -d /tmp/$dropbear_version ] && [ -d /tmp/$openssh_version ] && [ -d /tmp/$openssl_version ];then
echo -e "解压软件源码包成功" "\033[32m Success\033[0m"
else
echo -e "解压软件源码包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#安装远程软件
if [ "$rhel4_version" == "1" ] || [ "$rhel5_version" == "1" ];then
yum -y install xinetd telnet-server > /dev/null 2>&1
sed -i '/disable/d' /etc/xinetd.d/telnet
sed -i '/log_on_failure/a disable  = no' /etc/xinetd.d/telnet
sed -i '/disable/d' /etc/xinetd.d/telnet
sed -i '/log_on_failure/a disable  = no' /etc/xinetd.d/krb5-telnet > /dev/null 2>&1
mv /etc/securetty /etc/securetty.bak_$date
service xinetd restart > /dev/null 2>&1
fi

if [ "$rhel6_version" == "1" ] || [ "$rhel7_version" == "1" ];then
cd /tmp
tar xjf $dropbear_version.tar.bz2
cd $dropbear_version
./configure --disable-zlib > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1
mkdir /etc/dropbear
/usr/local/bin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
/usr/local/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbear -p 6666 > /dev/null 2>&1
fi

#备份旧版OpenSSH
rpm -ql openssh > /tmp/backup_$date/openssh/openssh-rpm-backup-list.txt
rpm -ql openssh-server > /tmp/backup_$date/openssh/openssh-server-rpm-backup-list.txt
find / -name "ssh*" > /tmp/backup_$date/openssh/openssh-backup-list.txt

if [ "$openssh_rpm_status" != "0" ];then
cp /usr/bin/ssh* /tmp/backup_$date/openssh/usr/bin > /dev/null 2>&1
cp /usr/sbin/sshd /tmp/backup_$date/openssh/usr/sbin > /dev/null 2>&1
cp /etc/init.d/sshd /tmp/backup_$date/openssh/etc/init.d > /dev/null 2>&1
cp /etc/pam.d/sshd /tmp/backup_$date/openssh/etc/pam.d > /dev/null 2>&1
cp /etc/ssh/ssh* /tmp/backup_$date/openssh/etc/ssh > /dev/null 2>&1
cp /etc/ssh/sshd_config /tmp/backup_$date/openssh/etc/ssh > /dev/null 2>&1
cp /usr/share/man/man1/ssh* /tmp/backup_$date/openssh/usr/share/man/man1 > /dev/null 2>&1
cp /usr/share/man/man8/ssh* /tmp/backup_$date/openssh/usr/share/man/man8 > /dev/null 2>&1
cp /usr/libexec/openssh/ssh* /tmp/backup_$date/openssh/usr/libexec/openssh > /dev/null 2>&1
service sshd stop > /dev/null 2>&1
yum -y remove openssh-server openssh > /dev/null 2>&1
else
mv /usr/bin/ssh* /tmp/backup_$date/openssh/usr/bin > /dev/null 2>&1
mv /usr/sbin/sshd /tmp/backup_$date/openssh/usr/sbin > /dev/null 2>&1
mv /etc/init.d/sshd /tmp/backup_$date/openssh/etc/init.d > /dev/null 2>&1
mv /etc/pam.d/sshd /tmp/backup_$date/openssh/etc/pam.d > /dev/null 2>&1
mv /etc/ssh/ssh* /tmp/backup_$date/openssh/etc/ssh > /dev/null 2>&1
mv /etc/ssh/sshd_config /tmp/backup_$date/openssh/etc/ssh > /dev/null 2>&1
mv /usr/share/man/man1/ssh* /tmp/backup_$date/openssh/usr/share/man/man1 > /dev/null 2>&1
mv /usr/share/man/man8/ssh* /tmp/backup_$date/openssh/usr/share/man/man8 > /dev/null 2>&1
mv /usr/libexec/openssh/ssh* /tmp/backup_$date/openssh/usr/libexec/openssh > /dev/null 2>&1
fi

#安装OpenSSL
cd /tmp
tar xzf $openssl_version.tar.gz
cd $openssl_version
./config --prefix=$prefix/$openssl_version --openssldir=$prefix/$openssl_version/ssl -fPIC > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装OpenSSL失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

if [ -e $prefix/$openssl_version/bin/openssl ];then
echo "$prefix/$openssl_version/lib" >> /etc/ld.so.conf
ldconfig
echo -e "编译安装OpenSSL成功" "\033[32m Success\033[0m"
fi
echo ""

#安装OpenSSH
cd /tmp
tar xzf $openssh_version.tar.gz  
cd $openssh_version
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-ssl-dir=$prefix/$openssl_version --with-zlib=$prefix/$zlib_version --with-pam --with-md5-passwords > /dev/null 2>&1
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

#启动OpenSSH
cp -rf /tmp/$openssh_version/contrib/redhat/sshd.init /etc/init.d/sshd
cp -rf /tmp/$openssh_version/contrib/redhat/sshd.pam /etc/pam.d/sshd
chmod +x /etc/init.d/sshd
chkconfig --add sshd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
if [ "$rhel7_version" == "1" ];then
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key
service sshd start > /dev/null 2>&1
else
service sshd start > /dev/null 2>&1
fi

if [ "$openssh_running_status" != "0" ];then
echo -e "启动OpenSSH服务成功" "\033[32m Success\033[0m"
echo ""
$prefix/$openssl_version/bin/openssl version
echo ""
ssh -V
else
echo -e "启动OpenSSH服务失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""

#删除源码包
rm -rf /tmp/$openssl_version*
rm -rf /tmp/$openssh_version*
rm -rf /tmp/$dropbear_version*
rm -rf /tmp/$zlib_version*

#卸载telnet
if [ "$rhel4_version" == "1" ] || [ "$rhel5_version" = "1" ];then
echo -e "\033[33m为防止OpenSSH升级失败导致无法远程登录，脚本已临时安装Telnet\033[0m"
echo ""
echo -e "\033[33mOpenSSH升级完成后，建议登录测试，确保没有问题后可卸载Telnet\033[0m"
echo ""
echo -e "\033[36m1: 卸载Telnet\033[0m"
echo ""
echo -e "\033[36m2: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车键: " uninstall
if [ "$uninstall" == "1" ];then
clear
yum -y remove telnet-server > /dev/null 2>&1
service xinetd stop > /dev/null 2>&1
mv /etc/securetty.bak_$date /etc/securetty
if [ "$telnet_rpm_status" == "0" ];then
echo -e "卸载Telnet成功" "\033[32m Success\033[0m"
else
echo -e "卸载Telnet失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
fi
fi

#卸载dropbear
if [ "$rhel6_version" == "1" ] || [ "$rhel7_version" == "1" ];then
echo -e "\033[33m为防止OpenSSH升级失败导致无法远程登录，脚本已临时安装DropBear\033[0m"
echo ""
echo -e "\033[33mOpenSSH升级完成后，建议登录测试，确保没有问题后可卸载DropBear\033[0m"
echo ""
echo -e "\033[36m1: 卸载DropBear\033[0m"
echo ""
echo -e "\033[36m2: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车键: " uninstall
if [ "$uninstall" == "1" ];then
clear
ps aux | grep dropbear | grep -v grep | awk '{print $2}' | xargs kill -9
find /usr/local/ -name dropbear* | xargs rm -rf
rm -rf /etc/dropbear
rm -rf /var/run/dropbear.pid
if [ "$dropbear_running_status" == "0" ];then
echo -e "卸载DropBear成功" "\033[32m Success\033[0m"
else
echo -e "卸载DropBear失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
fi
fi
echo ""
}

#脚本菜单
echo -e "\033[36m1: 升级软件\033[0m"
echo ""
echo -e "\033[36m2: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车开始执行脚本: " select
if [ "$select" == "1" ];then
clear
update
else
clear
exit
fi
