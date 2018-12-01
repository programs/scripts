#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/home/bin:~/bin
export PATH

# wget https://raw.githubusercontent.com/programs/scripts/master/vps/setup.sh && chmod +x setup.sh && bash setup.sh

GreenFont="\033[32m" && RedFont="\033[31m" && GreenBack="\033[42;37m" && RedBack="\033[41;37m" && FontEnd="\033[0m"
Info="${GreenFont}[信息]${FontEnd}"
Error="${RedFont}[错误]${FontEnd}"
Tip="${GreenFont}[注意]${FontEnd}"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')

function checkRoot()
{
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${GreenBack} sudo su ${FontEnd}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}

#检查系统
function checkSystem()
{
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}

function modifyRoot()
{
	if [ ! -f ~/rootdone ]; then 
		echo -e "${Info}请修改ROOT密码"
		stty erase '^H' && read -p "(回车，默认密码为Q1w@23e#888_+):" rootpasswd
		[[ -z "${rootpasswd}" ]] && rootpasswd='Q1w@23e#888_+'

		#echo "${rootpasswd}" | passwd root --stdin > /dev/null 2>&1
		echo root:${rootpasswd} | chpasswd
		touch ~/rootdone
	fi

	if [ ! -d /home/bin ]; then
		rm -rf /home/bin
		mkdir -p /home/bin
	fi
	if [ ! -d /home/frp ]; then
		rm -rf /home/frp
		mkdir -p /home/frp
	fi
}

function updateSystem()
{
	echo -e "${Info}正在更新系统..."
	apt-get update
	sleep 1s
	apt-get upgrade -y
	echo -e "${Info}更新系统完成."
}

function createUser()
{
	echo -e "${Info}请输入 将要创建的用户名"
	stty erase '^H' && read -p "(回车，默认用户名为adminer):" username
	[[ -z "${username}" ]] && username='adminer'

	exist_user=`cat /etc/passwd | grep ${username} | awk -F ':' '{print $1}'`
	if [ -z "${exist_user}" ]; then

		useradd -d "/home/${username}" -m -s "/bin/bash" ${username}

		echo -e "${Info}请输入 用户对应的密码"
		stty erase '^H' && read -p "(回车，默认密码为Q1w@23e#666_+):" userpasswd
		[[ -z "${userpasswd}" ]] && userpasswd='Q1w@23e#666_+'
		#echo "${userpasswd}" | passwd ${username} --stdin > /dev/null 2>&1
		echo ${username}:${userpasswd} | chpasswd

		usermod -a -G sudo ${username}
	else
		echo -e "${Tip}要创建的用户名${GreenBack} ${username} ${FontEnd}已经存在"
	fi
}

function installddos()
{
	if [ -d '/usr/local/ddos' ]; then
		echo -e "${Tip}DDOS 已经安装，若要重新安装请首先卸载之前的 DDOS 版本."
	else
		mkdir /usr/local/ddos

		echo -e "${Info}正在安装 DDOS";
		wget -q -O /usr/local/ddos/ddos.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/ddos.conf
		wget -q -O /usr/local/ddos/ignore.ip.list https://raw.githubusercontent.com/programs/scripts/master/vps/config/ignore.ip.list
		wget -q -O /usr/local/ddos/ddos.sh https://raw.githubusercontent.com/programs/scripts/master/vps/config/ddos.sh
		chmod 0755 /usr/local/ddos/ddos.sh
		cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

		echo -e "${Info}按照默认设置 DDOS 运行任务....."
		/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
		echo -e "${Info}DDOS 安装完成."
	fi
}

function createSwap()
{
	tram_size=$( free -m | awk '/Mem/ {print $2}' )
	swap_size=$( free -m | awk '/Swap/ {print $2}' )
    swap_count=`swapon -s | grep -v 'Filename' |  awk '{print $1}' | wc -l`
	if [[ "${swap_count}" -lt "1" ]]; then

        echo -e "${Info}当前系统不存在交换分区，正在创建交换分区..."
	    gsize=`expr ${tram_size} / 1024`
		bsize=512
		if [ ${gsize} -gt 64 ]; then
		    ssize=16384
	    elif [ ${gsize} -gt 8 ]; then 
		    ssize=8192
	    elif [ ${gsize} -gt 4 ]; then
		    ssize=${tram_size}
	    else
		    ssize=`expr ${tram_size} * 2`
			if [ ${tram_size} -lt ${bsize} ]; then
			    bsize=${tram_size}
			fi
		fi

		bcount=`expr ${ssize} / ${bsize}`
		dd if=/dev/zero of=/swapfile bs=${bsize}M count=${bcount}
		ls -lh /swapfile
		chmod 600 /swapfile
		mkswap /swapfile
		swapon /swapfile
		echo "/swap none swap sw 0 0" >> /etc/fstab

		swap_size=$( free -m | awk '/Swap/ {print $2}' )
		echo -e "${Info}创建交换分区完成，大小为${GreenFont} ${swap_size}M ${FontEnd}"
	else
		echo -e "${Info}当前系统交换分区已存在，大小为${GreenFont} ${swap_size}M ${FontEnd}"
	fi
}

function setupSsrmu()
{
	if [ ! -s /usr/local/shadowsocksr/user-config.json ]; then
		echo -e "${Info}正在安装 SSR (SSR将安装默认设置自动完成) ..."
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ssrmu.sh
		chmod +x /home/bin/ssrmu.sh
		/home/bin/ssrmu.sh

		wget -q -O /usr/local/shadowsocksr/user-config.json https://raw.githubusercontent.com/programs/scripts/master/vps/config/user-config.json
		echo -e "${Info}SSR 已完成安装."
	else
		echo -e "${Info}SSR 已安装."
	fi
}

function installServices()
{
	sleep 1s
	echo -e "${Info}正在安装必要的系统软件..."
	apt-get install -y --no-install-recommends virt-what fail2ban supervisor

	sleep 1s
	echo -e "${Info}正在下载源文件..."
	wget -q -O /home/frp/frps https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps
	wget -q -O /home/frp/frpstart https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frpstart
	wget -q -O /home/frp/frps.ini https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps.ini

	chmod +x /home/frp/frps
	chmod +x /home/frp/frpstart

	wget -q -O /etc/ssh/sshd_config https://raw.githubusercontent.com/programs/scripts/master/vps/config/sshd_config
	wget -q -O /etc/fail2ban/jail.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/jail.conf
	wget -q -O /etc/supervisor/conf.d/frp.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/frp.conf
	wget -q -O /etc/iptables.up.rules https://raw.githubusercontent.com/programs/scripts/master/vps/config/iptables.up.rules

	service sshd restart
	service fail2ban restart
	sleep 1s
	fail2ban-client status
	systemctl restart supervisor
	sleep 1s
	supervisorctl status
	iptables-restore < /etc/iptables.up.rules

	echo -e "${Info}系统软件安装完成."
}

function setupBBR()
{
	wget -q -O /home/bin/bbr.sh https://raw.githubusercontent.com/programs/scripts/master/vps/bbr.sh
	chmod +x /home/bin/bbr.sh
	/home/bin/bbr.sh
}

function initinstall()
{
	checkRoot
	modifyRoot
	updateSystem
	createUser
	installddos
	createSwap
	setupSsrmu
	installServices
	setupBBR
}

#主程序入口
checkSystem
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
action=$1
[[ -z $1 ]] && action=install
case "$action" in
	install)
	init${action}
	;;
	*)
	echo "输入错误 !"
	echo "用法: { install }"
	;;
esac
