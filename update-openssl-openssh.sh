#!/bin/bash
clear

####### 通用代码 #######

#脚本变量
#编译升级更新版本的源码包，可以根据软件官网版本号修改xx_version；
date=`date "+%Y%m%d"`
zlib_version="zlib-1.2.11"
dropbear_version="dropbear-2018.76"
openssl_version="openssl-1.0.2p"
openssh_version="openssh-7.9p1"
zlib_download="http://zlib.net/$zlib_version.tar.gz"
dropbear_download="https://matt.ucc.asn.au/dropbear/releases/$dropbear_version.tar.bz2"
openssl_download="https://www.openssl.org/source/$openssl_version.tar.gz"
openssh_download="https://openbsd.hk/pub/OpenBSD/OpenSSH/portable/$openssh_version.tar.gz"
system_version=`cat /etc/redhat-release`
rhel4_version=`cat /etc/redhat-release | grep "release 4" | wc -l`
rhel5_version=`cat /etc/redhat-release | grep "release 5" | wc -l`
rhel6_version=`cat /etc/redhat-release | grep "release 6" | wc -l`
rhel7_version=`cat /etc/redhat-release | grep "release 7" | wc -l`
gcc_intall_status==`rpm -qa | grep -w gcc | wc -l`
gcc_c_intall_status==`rpm -qa | grep -w gcc-c++ | wc -l`
pam_devel_intall_status==`rpm -qa | grep pam-devel | wc -l`
bzip2_intall_status=`rpm -qa | grep bzip2 | wc -l`
wget_intall_status=`rpm -qa | grep wget | wc -l`
make_intall_status=`rpm -qa | grep make | wc -l`
openssl_rpm_status=`rpm -qa | grep -w openssl | wc -l`
openssh_rpm_status=`rpm -qa | grep -w openssh-server | wc -l`
telnet_rpm_status=`rpm -qa | grep -w telnet-server | wc -l`
openssh_running_status=`ps aux | grep sshd | grep -v grep | wc -l`

#检查当前用户是否为root
if [ $(id -u) != 0 ]; then
echo -e "当前登陆用户为普通用户，必须使用Root用户运行脚本，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

#使用说明
echo -e "\033[33m《一键升级OpenSSL、OpenSSH脚本》使用说明\033[0m"
echo ""
echo "A.一键升级脚本仅适用于RHEL/CentOS操作系统，支持4.x、5.x、6.x、7.x各系统版本；"
echo "B.必须使用Root用户运行脚本，并确保本机已配置好软件仓库以及可以正常访问互联网；"
echo "C.RHEL4.x - 5.x操作系统会临时安装Telnet，通信端口为23，升级结束后会引导卸载；"
echo "D.RHEL6.x - 7.x操作系统会临时安装DropBear，通信端口为6666，升级结束后会引导卸载；"
echo "E.本机旧版本的OpenSSL、OpenSSH、Lib库文件全部备份在/tmp/backup_$date文件夹。"
echo ""

#判断操作系统
echo "当前本机操作系统版本："$system_version
echo ""

#最新软件版本
echo "当前官网最新软件版本："$openssl_version、$openssh_version
echo ""

#禁用SElinux
setenforce 0 > /dev/null 2>&1

#禁用防火墙
service iptables stop > /dev/null 2>&1
service ip6tables stop > /dev/null 2>&1

####### 通用代码 #######

####### 升级软件 #######
function update() {
echo -e "\033[33m开始升级OpenSSL、OpenSSH\033[0m"
echo ""

#安装软件依赖包
yum -y install gcc gcc-c++ pam-devel bzip2 wget make > /dev/null 2>&1
cd /tmp
wget --no-check-certificate $zlib_download > /dev/null 2>&1
tar xzf $zlib_version.tar.gz
cd /tmp/$zlib_version
./configure --shared > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1
if [ $gcc_intall_status != 0 ] && [ $gcc_c_intall_status != 0 ] && [ $pam_devel_intall_status != 0 ] && [ $bzip2_intall_status != 0 ] && [ $wget_intall_status != 0 ] && [ $make_intall_status != 0 ] && [ -e /usr/local/lib/libz.so ];then
echo -e "安装软件依赖包成功" "\033[32m Success\033[0m"
else
echo -e "安装软件依赖包失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi
echo ""

#解压软件源码包
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
if [ $rhel4_version == 1 ] || [ $rhel5_version == 1 ];then
yum -y install telnet-server xinetd > /dev/null 2>&1
sed -i '/disable/d' /etc/xinetd.d/telnet
sed -i '/log_on_failure/a disable  = no' /etc/xinetd.d/telnet
sed -i '/disable/d' /etc/xinetd.d/telnet
sed -i '/log_on_failure/a disable  = no' /etc/xinetd.d/krb5-telnet
mv /etc/securetty /etc/securetty.bak
service xinetd restart > /dev/null 2>&1
fi

if [ $rhel6_version == 1 ] || [ $rhel7_version == 1 ];then
cd /tmp
tar xjf $dropbear_version.tar.bz2
cd $dropbear_version
./configure > /dev/null 2>&1
make > /dev/null 2>&1
make install > /dev/null 2>&1
mkdir /etc/dropbear
/usr/local/bin/dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key > /dev/null 2>&1
/usr/local/bin/dropbearkey -t rsa -s 4096 -f /etc/dropbear/dropbear_rsa_host_key > /dev/null 2>&1
/usr/local/sbin/dropbear -p 6666 > /dev/null 2>&1
fi

#备份旧版本lib
service sshd stop > /dev/null 2>&1
mkdir /tmp/backup_$date
if [ $(getconf WORD_BIT) == 32 ] && [ $(getconf LONG_BIT) == 64 ];then
ls -lhR /lib > /tmp/backup_$date/old_lib_list.txt
ls -lhR /usr/lib > /tmp/backup_$date/old_usr_lib_list.txt
ls -lhR /lib64 > /tmp/backup_$date/old_lib64_list.txt
ls -lhR /usr/lib64 > /tmp/backup_$date/old_usr_lib64_list.txt
tar czf /tmp/backup_$date/lib_backup.tar.gz /lib > /dev/null 2>&1
tar czf /tmp/backup_$date/usr_lib_backup.tar.gz /usr/lib > /dev/null 2>&1
tar czf /tmp/backup_$date/lib64_backup.tar.gz /lib64 > /dev/null 2>&1
tar czf /tmp/backup_$date/usr_lib64_backup.tar.gz /usr/lib64 > /dev/null 2>&1
else
ls -lhR /lib > /tmp/backup_$date/old_lib_list.txt
ls -lhR /usr/lib > /tmp/backup_$date/old_usr_lib_list.txt
tar czf /tmp/backup_$date/lib_backup.tar.gz /lib > /dev/null 2>&1
tar czf /tmp/backup_$date/usr_lib_backup.tar.gz /usr/lib > /dev/null 2>&1
fi

#备份旧版本openssl
if  [ $openssl_rpm_status != 0 ];then
rpm -ql `rpm -qa | egrep openssl` > /tmp/backup_$date/old_openssl_list.txt
tar czf /tmp/backup_$date/openssl_backup.tar.gz -T /tmp/backup_$date/old_openssl_list.txt > /dev/null 2>&1
else
find / -name *ssl* > /tmp/backup_$date/old_openssl_list.txt
tar czf /tmp/backup_$date/openssl_backup.tar.gz -T /tmp/backup_$date/old_openssl_list.txt > /dev/null 2>&1
fi

#备份旧版本openssh
if [ $openssh_rpm_status != 0 ];then
rpm -ql `rpm -qa | egrep openssh` > /tmp/backup_$date/old_openssh_list.txt
tar czf /tmp/backup_$date/openssh_backup.tar.gz -T /tmp/backup_$date/old_openssh_list.txt > /dev/null 2>&1
else
find / -name *ssh* > /tmp/backup_$date/old_openssh_list.txt
tar czf /tmp/backup_$date/openssh_backup.tar.gz -T /tmp/backup_$date/old_openssh_list.txt > /dev/null 2>&1
fi

#检查备份结果
if [ $(getconf WORD_BIT) == 32 ] && [ $(getconf LONG_BIT) == 64 ] && [ -e /tmp/backup_$date/lib_backup.tar.gz ] && [ -e /tmp/backup_$date/usr_lib_backup.tar.gz ]&& [ -e /tmp/backup_$date/lib64_backup.tar.gz ] && [ -e /tmp/backup_$date/usr_lib64_backup.tar.gz ] && [ -e /tmp/backup_$date/openssl_backup.tar.gz ] && [ -e /tmp/backup_$date/openssh_backup.tar.gz ];then
echo -e "备份旧版本程序成功" "\033[32m Success\033[0m"
fi
if [ $(getconf WORD_BIT) == 32 ] && [ $(getconf LONG_BIT) == 32 ] && [ -e /tmp/backup_$date/lib_backup.tar.gz ] && [ -e /tmp/backup_$date/usr_lib_backup.tar.gz ] && [ -e /tmp/backup_$date/openssl_backup.tar.gz ] && [ -e /tmp/backup_$date/openssh_backup.tar.gz ];then
echo -e "备份旧版本程序成功" "\033[32m Success\033[0m"
fi
echo ""

#卸载旧版本openssl
if [ -e /usr/bin/openssl ];then
mv /usr/bin/openssl /usr/bin/openssl.bak_$date
fi
if [ -e /usr/lib/openssl ];then
mv /usr/lib/openssl /usr/lib/openssl.bak_$date
fi
if [ -e /usr/lib64/openssl ];then
mv /usr/lib64/openssl /usr/lib64/openssl.bak_$date
fi

#卸载旧版本openssh
if  [ $openssh_rpm_status != 0 ];then
rpm -e `rpm -qa | grep openssh` --nodeps  --allmatches > /dev/null 2>&1
else
mv /usr/bin/scp /usr/bin/scp.bak_$date > /dev/null 2>&1
mv /usr/bin/sftp /usr/bin/sftp.bak_$date > /dev/null 2>&1
mv /usr/bin/ssh /usr/bin/ssh.bak_$date > /dev/null 2>&1
mv /usr/bin/ssh-keyscan /usr/bin/ssh-keyscan.bak_$date > /dev/null 2>&1
mv /usr/bin/ssh-add /usr/bin/ssh-add.bak_$date > /dev/null 2>&1
mv /usr/bin/ssh-keygen /usr/bin/ssh-keygen.bak_$date > /dev/null 2>&1
mv /usr/bin/ssh-agent /usr/bin/ssh-agent.bak_$date > /dev/null 2>&1
mv /usr/libexec/ssh-pkcs11-helper /usr/libexec/ssh-pkcs11-helper.bak_$date > /dev/null 2>&1
mv /usr/libexec/ssh-keysign /usr/libexec/ssh-keysign.bak_$date > /dev/null 2>&1
mv /usr/libexec/sftp-server /usr/libexec/sftp-server.bak_$date > /dev/null 2>&1
mv /usr/sbin/sshd /usr/sbin/sshd.bak_$date > /dev/null 2>&1
mv /etc/ssh /etc/ssh.bak_$date > /dev/null 2>&1
mv /etc/init.d/sshd /etc/init.d/sshd.bak_$date > /dev/null 2>&1
fi

#检查卸载结果
if [ $openssh_rpm_status != 0 ] && [ -e /usr/bin/openssl ];then
echo -e "卸载旧版本程序失败" "\033[31m Failure\033[0m"
else
echo -e "卸载旧版本程序成功" "\033[32m Success\033[0m"
fi
echo ""

#编译安装OpenSSL
cd /tmp
tar xzf $openssl_version.tar.gz
cd $openssl_version
./config -fPIC --prefix=/usr enable-shared > /dev/null 2>&1
if [ $? -eq 0 ];then
make > /dev/null 2>&1
make install > /dev/null 2>&1
else
echo -e "编译安装OpenSSL失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
echo ""
sleep 5
exit
fi

if [ -e /usr/bin/openssl ];then
echo -e "编译安装OpenSSL成功" "\033[32m Success\033[0m"
fi
echo ""

#编译安装OpenSSH
cd /tmp
tar xzf $openssh_version.tar.gz  
cd $openssh_version
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-pam --with-zlib > /dev/null 2>&1
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
if [ $rhel7_version == 1 ];then
chmod 600 /etc/ssh/ssh_host_rsa_key
chmod 600 /etc/ssh/ssh_host_ecdsa_key
chmod 600 /etc/ssh/ssh_host_ed25519_key
fi
service sshd start > /dev/null 2>&1
if [ $openssh_running_status != 0 ];then
echo -e "启动OpenSSH服务成功" "\033[32m Success\033[0m"
else
echo -e "启动OpenSSH服务失败，五秒后自动退出脚本" "\033[31m Failure\033[0m"
sleep 5
exit
fi
echo ""

#删除软件源码包
rm -rf /tmp/$openssh_version*
rm -rf /tmp/$openssl_version*
rm -rf /tmp/$zlib_version*
rm -rf /tmp/$dropbear_version*
if [ -e /tmp/$openssh_version ] && [ -e /tmp/$openssl_version ] && [ -e /tmp/$openssl_version ] && [ -e /tmp/$zlib_version ] && [ -e /tmp/$openssh_version.tar.gz ] && [ -e /tmp/$openssl_version.tar.gz ] && [ -e /tmp/$zlib_version.tar.gz ] && [ -e /tmp/$dropbear_version.tar.gz ];then
echo -e "删除软件源码包失败" "\033[31m Failure\033[0m"
else
echo -e "删除软件源码包成功" "\033[32m Success\033[0m"
fi
echo ""

#升级完成
echo -e "\033[33mOpenSSH、OpenSSL升级成功，软件版本如下：\033[0m"
echo ""
openssl version
echo ""
ssh -V
echo ""

#卸载telnet
if [ $rhel4_version == 1 ] || [ $rhel5_version = 1 ];then
echo -e "\033[33m为防止OpenSSH升级失败导致无法远程登录，脚本已临时安装Telnet\033[0m"
echo ""
echo -e "\033[33mOpenSSH升级完成后，建议登录测试，确保没有问题后可卸载Telnet\033[0m"
echo ""
echo "1: 卸载Telnet"
echo ""
echo "2: 退出脚本"
echo ""
read -p  "请输入对应数字后按回车键: " uninstall
if [ $uninstall == 1 ];then
clear
yum -y remove telnet-server > /dev/null 2>&1
service xinetd stop > /dev/null 2>&1
mv /etc/securetty.bak /etc/securetty
echo -e "卸载Telnet成功" "\033[32m Success\033[0m"
else
exit
fi
fi

#卸载dropbear
if [ $rhel6_version == 1 ] || [ $rhel7_version == 1 ];then
echo -e "\033[33m为防止OpenSSH升级失败导致无法远程登录，脚本已临时安装DropBear\033[0m"
echo ""
echo -e "\033[33mOpenSSH升级完成后，建议登录测试，确保没有问题后可卸载DropBear\033[0m"
echo ""
echo "1: 卸载DropBear"
echo ""
echo "2: 退出脚本"
echo ""
read -p  "请输入对应数字后按回车键: " uninstall
if [ $uninstall == 1 ];then
clear
ps aux | grep dropbear | grep -v grep | awk '{print $2}' | xargs kill -9
find /usr/local/ -name dropbear* | xargs rm -rf
rm -rf /etc/dropbear
rm -rf /var/run/dropbear.pid
echo -e "卸载DropBear成功" "\033[32m Success\033[0m"
fi
fi
echo ""
}
####### 升级软件 #######

####### 脚本菜单 #######
echo -e "\033[36m1: 升级软件\033[0m"
echo ""
echo -e "\033[36m2: 退出脚本\033[0m"
echo ""
read -p  "请输入对应数字后按回车开始执行脚本: " install
if [ "$install" == "1" ];then
clear
update
else
clear
exit
fi
####### 脚本菜单 #######