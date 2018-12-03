#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/home/bin:~/bin
export PATH

LANG=en_US.UTF-8
is64bit=`getconf LONG_BIT`

# 用法
# rm -f /usr/bin/vps && wget -N --no-check-certificate -q -O /usr/bin/vps https://raw.githubusercontent.com/programs/scripts/master/vps/setup.sh && chmod +x /usr/bin/vps && vps
#
GreenFont="\033[32m" && RedFont="\033[31m" && GreenBack="\033[42;37m" && RedBack="\033[41;37m" && FontEnd="\033[0m"
Info="${GreenFont}[信息]${FontEnd}"
Error="${RedFont}[错误]${FontEnd}"
Tip="${GreenFont}[注意]${FontEnd}"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')
fsudo=''
defaultuser='adminer'

# 第三方URL定义
ssrmu_url='https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ssrmu.sh'
zbanch_url='https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh'
sbanch_url='https://raw.githubusercontent.com/oooldking/script/master/superbench.sh'
ipaddr_url='https://www.bt.cn/Api/getIpAddress'
nodequery_url='https://raw.github.com/nodequery/nq-agent/master/nq-install.sh'

function checkRoot()
{
	[[ $EUID != 0 ]] && echo -e "${Error} 当前账号非ROOT(或没有ROOT权限)，无法继续操作，请使用${GreenBack} sudo su ${FontEnd}来获取临时ROOT权限（执行后会提示输入当前账号的密码）。" && exit 1
}

function checksudo()
{
	if [ `whoami` != "root" ]; then
		fsudo='sudo '
	fi
}

# 检查系统类型
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
	checksudo
}

function configRoot()
{
	if [ ! -f ~/rootdone ]; then 

		locale-gen en_US.UTF-8
		dpkg-reconfigure locales

		rm -rf /etc/localtime
		ln -s /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime 

		defaultpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 16`
		echo -e "${Info}请修改ROOT密码"
		stty erase '^H' && read -p "(回车，默认密码为 ${defaultpwd}):" rootpasswd
		[[ -z "${rootpasswd}" ]] && rootpasswd=${defaultpwd}

		#echo "${rootpasswd}" | passwd root --stdin > /dev/null 2>&1
		echo root:${rootpasswd} | chpasswd
		touch ~/rootdone
	fi

	if [ ! -d /home/bin ]; then
		rm -rf /home/bin
		mkdir -p /home/bin
		echo "export PATH=$PATH:/home/bin" >> ~/.bashrc
	fi
	if [ ! -d /home/frp ]; then
		rm -rf /home/frp
		mkdir -p /home/frp
	fi
}

function updateSystem()
{
	apt-get update
	
	stty erase '^H' && read -p "是否需要更新系统 ? [y/N] :" yn
	[[ -z "${yn}" ]] && yn="n"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info}正在更新系统..."
		apt-get upgrade -y
		echo -e "${Info}更新系统完成."
	fi
}

function createUser()
{
	echo -e "${Info}请输入 将要创建的用户名"
	stty erase '^H' && read -p "(回车，默认用户名为 ${defaultuser}):" username
	[[ -z "${username}" ]] && username=${defaultuser}

	exist_user=`cat /etc/passwd | grep ${username} | awk -F ':' '{print $1}'`
	if [ -z "${exist_user}" ]; then

		useradd -d "/home/${username}" -m -s "/bin/bash" ${username}

		userdefpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 16`
		echo -e "${Info}请输入 用户对应的密码"
		stty erase '^H' && read -p "(回车，默认密码为 ${userdefpwd}):" userpasswd
		[[ -z "${userpasswd}" ]] && userpasswd=${userdefpwd}
		#echo "${userpasswd}" | passwd ${username} --stdin > /dev/null 2>&1
		echo ${username}:${userpasswd} | chpasswd

		usermod -aG sudo ${username}
		echo "export PATH=$PATH:/home/bin" >> /home/${username}/.bashrc

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
		rf -f /usr/local/ddos/ddos.conf
		rf -f /usr/local/ddos/ignore.ip.list
		rf -f /usr/local/ddos/ddos.sh

		wget -N --no-check-certificate -q -O /usr/local/ddos/ddos.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/ddos.conf
		wget -N --no-check-certificate -q -O /usr/local/ddos/ignore.ip.list https://raw.githubusercontent.com/programs/scripts/master/vps/config/ignore.ip.list
		wget -N --no-check-certificate -q -O /usr/local/ddos/ddos.sh https://raw.githubusercontent.com/programs/scripts/master/vps/config/ddos.sh
		chmod 0755 /usr/local/ddos/ddos.sh
		cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos

		echo -e "${Info}按照默认设置 DDOS 运行任务....."
		/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
		echo -e "${Info}DDOS 安装完成."
	fi
}

function createSwap()
{
	need_swap=''
	swapfile='/swapdisk'

	tram_size=$( free -m | awk '/Mem/ {print $2}' )
	swap_size=$( free -m | awk '/Swap/ {print $2}' )
    swap_count=`swapon -s | grep -v 'Filename' | awk '{print $1}' | wc -l`
	if [[ "${swap_count}" -lt "1" ]]; then
		echo -e "${Info}当前系统不存在交换分区，正在创建交换分区..."

		tmpswapfile=`cat /etc/fstab | grep 'swap' | grep -v 'dev' | awk '{print $1}'`
		if [ -f ${tmpswapfile} ]; then

			echo -e "${Info}正在移除原有交换分区..."
			swapoff ${swap_file}
			sleep 2s
			rm -f ${swap_file}

			delSwapfile=`echo ${tmpswapfile} | sed 's#\/#\\\/#g'`
			[[ ! -z "${delSwapfile}" ]] && sed -i "/${delSwapfile}/d" /etc/fstab
		fi
		need_swap='do'
	else
		echo -e "${Info}当前系统交换分区已存在，大小为${GreenFont} ${swap_size}M ${FontEnd}"

		swap_file=`swapon -s | grep -v 'Filename' | grep -v 'dev' | awk '{print $1}'`
		if [ -f ${swap_file} ]; then
			stty erase '^H' && read -p "是否重新创建交换分区? [Y/n] :" ynt
			[[ -z "${ynt}" ]] && ynt="y"
			if [[ $ynt == [Yy] ]]; then
				swapfile=${swap_file}

				echo -e "${Info}正在移除原有交换分区..."
				swapoff ${swap_file}
				sleep 2s
				rm -f ${swap_file}

				delSwapfile=`echo ${swap_file} | sed 's#\/#\\\/#g'`
				[[ ! -z "${delSwapfile}" ]] && sed -i "/${delSwapfile}/d" /etc/fstab
				need_swap='do'
			fi
		fi
	fi

	if [ "x${need_swap}" == "xdo" ]; then
		
		echo -e "${Info}当前物理内存为${GreenBack} ${tram_size}M ${FontEnd}"
		tty erase '^H' && read -p "请输入将要创建交换分区大小 (默认等于物理内存大小) :" inputsize
		[[ -z "${inputsize}" ]] && inputsize=${tram_size}
		dd if=/dev/zero of=${swapfile} bs=${inputsize}M count=1

		if [ -f ${swapfile} ]; then
			chmod 600 ${swapfile}
			mkswap ${swapfile}
			swapon ${swapfile}
			echo "${swapfile}    swap    swap    defaults    0 0" >> /etc/fstab

			swap_size=$( free -m | awk '/Swap/ {print $2}' )
			echo -e "${Info}创建交换分区完成，实际大小为${GreenFont} ${swap_size}M ${FontEnd}"
		else
			echo -e "${Error}创建交换分区失败!"
		fi
	fi
}

function setupSsrmu()
{
	apt-get install -y --no-install-recommends jq

	if [ ! -s /usr/local/shadowsocksr/user-config.json ]; then
		echo -e "${Info}正在安装 SSR (SSR将安装默认设置自动完成) ..."
		rm -f /home/bin/ssrmu.sh
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh ${ssrmu_url}
		chmod +x /home/bin/ssrmu.sh
		/home/bin/ssrmu.sh

		rm -f /usr/local/shadowsocksr/user-config.json
		wget -N --no-check-certificate -q -O /usr/local/shadowsocksr/user-config.json https://raw.githubusercontent.com/programs/scripts/master/vps/config/user-config.json

		stty erase '^H' && read -p "SSR 是否使用 IPv6 配置? [Y/n] :" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			ipv6flag='true'
			#/usr/local/shadowsocksr/user-config.json -> "dns_ipv6": false,
			cat /usr/local/shadowsocksr/user-config.json |
				jq 'to_entries | 
					map(if .key == "dns_ipv6" 
						then . + {"value":'${ipv6flag}'} 
						else . 
						end
						) | 
					from_entries'
			
			rm -f /etc/sysctl.d/99-ubuntu-ipv6.conf
			service procps reload
		fi
		echo -e "${Info}SSR 已完成安装."
	else
		echo -e "${Info}SSR 已安装."
	fi
}

function installFrp()
{
	echo -e "${Info}正在安装 FRP ..."

	if [ ! -d /home/frp ]; then
		mkdir -p /home/frp
	fi

	rm -f /home/frp/frps
	rm -f /home/frp/frpstart
	rm -f /home/frp/frps.ini

	wget -N --no-check-certificate -q -O /home/frp/frps https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps
	wget -N --no-check-certificate -q -O /home/frp/frpstart https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frpstart
	wget -N --no-check-certificate -q -O /home/frp/frps.ini https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps.ini

	if [ -f /home/frp/frps.ini ]; then

		chmod +x /home/frp/frps
		chmod +x /home/frp/frpstart
		echo -e "${Info}FRP 安装完成."

		do_frpsecurity
	else
		echo -e "${Error}FRP 安装出错."
	fi 
}

function setupServices()
{
	sleep 1s
	echo -e "${Info}正在安装必要的系统软件..."
	apt-get install -y --no-install-recommends virt-what fail2ban supervisor

	sleep 1s
	echo -e "${Info}正在下载源文件..."
	
	rm -f /etc/ssh/sshd_config
	rm -f /etc/fail2ban/jail.conf
	rm -f /etc/supervisor/conf.d/frp.conf
	rm -f /etc/iptables.up.rules

	wget -N --no-check-certificate -q -O /etc/ssh/sshd_config https://raw.githubusercontent.com/programs/scripts/master/vps/config/sshd_config
	wget -N --no-check-certificate -q -O /etc/fail2ban/jail.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/jail.conf
	wget -N --no-check-certificate -q -O /etc/supervisor/conf.d/frp.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/frp.conf
	wget -N --no-check-certificate -q -O /etc/iptables.up.rules https://raw.githubusercontent.com/programs/scripts/master/vps/config/iptables.up.rules

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
	if [ ! -f /home/bin/bbr.sh ]; then
		rm -f /home/bin/bbr.sh
		wget -N --no-check-certificate -q -O /home/bin/bbr.sh https://raw.githubusercontent.com/programs/scripts/master/vps/bbr.sh
		chmod +x /home/bin/bbr.sh
	fi
	/home/bin/bbr.sh
}

function do_install()
{
	configRoot
	updateSystem
	createUser
	installddos
	createSwap
	setupSsrmu
	installFrp
	setupServices
	setupBBR	
}

function do_speedtest()
{
	rm -f /home/bin/zbanch.sh
	wget -N --no-check-certificate -q -O /home/bin/zbanch.sh ${zbanch_url}
	chmod +x /home/bin/zbanch.sh
	/home/bin/zbanch.sh

	rm -f /home/bin/superbench.sh
	wget -N --no-check-certificate -q -O /home/bin/superbench.sh ${sbanch_url}
	chmod +x /home/bin/superbench.sh

	stty erase '^H' && read -p "是否需要进一步进行网络测试? [Y/n]:" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		mtr -rw www.baidu.com
		/home/bin/superbench.sh
	fi
}

function do_bbrstatus()
{
	if [ ! -f /home/bin/bbr.sh ]; then
		rm -f /home/bin/bbr.sh
		wget -N --no-check-certificate -q -O /home/bin/bbr.sh https://raw.githubusercontent.com/programs/scripts/master/vps/bbr.sh
		chmod +x /home/bin/bbr.sh
	fi
	/home/bin/bbr.sh status
}

function do_ssrstatus()
{
	#另一方法
	#ipaddr=`ip addr show eth0 | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | grep -v ':'`
	#curl -4 icanhazip.com

	ipaddr=`curl -sS --connect-timeout 10 -m 60 ${ipaddr_url}`
	echo -e "${Info}当前IP : ${GreenFont}${ipaddr}${FontEnd}"

	ssr_folder="/usr/local/shadowsocksr"
	if [[ -e ${ssr_folder} ]]; then
		PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
		if [[ ! -z "${PID}" ]]; then
			echo -e "${Info}当前状态: ${GreenFont}已安装${FontEnd} 并 ${GreenFont}已启动${FontEnd}"
		else
			echo -e "${Info}当前状态: ${GreenFont}已安装${FontEnd} 但 ${RedFont}未启动${FontEnd}"
		fi
	else
		echo -e "${Info}当前状态: ${RedFont}未安装${FontEnd}"
	fi
}

function do_ssrmu()
{
	if [ ! -f /home/bin/ssrmu.sh ]; then
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh ${ssrmu_url}
		chmod +x /home/bin/ssrmu.sh
	fi 
	/home/bin/ssrmu.sh	
}

function do_redoswap() {
	createSwap
}
function do_upgrade() { 
	updateSystem
}
function do_adduser() {
	createUser
}
function do_deluser()
{
	echo -e "${Info}请输入 将要删除的用户名"
	stty erase '^H' && read -p "(回车，默认用户名为 ${defaultuser}):" username
	[[ -z "${username}" ]] && username=${defaultuser}

	exist_user=`cat /etc/passwd | grep ${username} | awk -F ':' '{print $1}'`
	if [ ! -z "${exist_user}" ]; then

		echo -e "${RedFont}${Tip}删除用户 ${username} 将不可恢复!${FontEnd}"
		stty erase '^H' && read -p "请确认? [y/N]:" yn
		[[ -z "${yn}" ]] && yn="n"
		if [[ $yn == [Yy] ]]; then
			userdel ${username}
			groupdel ${username}
			echo -e "${Tip}用户${GreenFont} ${username} ${FontEnd}已删除!"
		fi
	else
		echo -e "${Error}要删除的用户名${GreenFont} ${username} ${FontEnd}不存在"
	fi
}

function do_iptable()
{
	vim /etc/iptables.up.rules
	stty erase '^H' && read -p "是否使防火墙立即生效 ? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		iptables-restore < /etc/iptables.up.rules

		# 如果存在 Docker 则需要重启其服务
		if [ -f /usr/bin/docker ]; then
			systemctl restart docker.service
		fi
		echo -e "${Info}防火墙设置成功!"
	fi
}

function do_editfrp()
{
	vim /home/frp/frps.ini
	stty erase '^H' && read -p "是否使FRP立即生效 ? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		systemctl restart supervisor
	fi
}

function do_configssh()
{
	sshPort=`cat /etc/ssh/sshd_config | grep 'Port ' | grep -oE [0-9] | tr -d '\n'`
	echo -e "${Info}当前 SSH 端口号:${GreenFont} ${sshPort} ${FontEnd}"

	stty erase '^H' && read -p "是否需要手动配置 SSH ? [Y/n] :" ynt
	[[ -z "${ynt}" ]] && ynt="y"
	if [[ $ynt == [Yy] ]]; then

		vim /etc/ssh/sshd_config
		stty erase '^H' && read -p "是否使SSH立即生效 ? [Y/n] :" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			service sshd restart
		fi
		echo -e "${Info}SSH 服务设置成功!"
	fi
}

function do_qsecurity()
{
	echo -e "${Info}服务器上所有的关于每个IP的连接数:"
	iplink_count=`netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n`
	echo -e "${iplink_count}"

	echo -e "${Info}尝试暴力破解机器密码的人:"
	pjman=`grep "Failed password for root" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -nr | more`
	echo -e "${pjman}"

	echo -e "${Info}暴力猜用户名的人:"
	blpjman=`grep "Failed password for invalid user" /var/log/auth.log | awk '{print $13}' | sort | uniq -c | sort -nr | more`
	echo -e "${blpjman}"
}

function do_frpsecurity()
{
	stty erase '^H' && read -p "是否需要设置 FRP 面板密码及其访问命牌? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		
		dashboardrand=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		stty erase '^H' && read -p "请输入 FRP 面板密码:" dashboardpwd
		[[ -z "${dashboardpwd}" ]] && dashboardpwd=${dashboardrand}

		privilegetokenrand=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		stty erase '^H' && read -p "请输入 FRP 访问命牌:" privilegetoken
		[[ -z "${privilegetoken}" ]] && privilegetoken=${privilegetokenrand}
		
	else
		dashboardpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		privilegetoken=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
	fi
	sed -i "/^dashboard_pwd/c\dashboard_pwd = ${dashboardpwd}" /home/frp/frps.ini
	sed -i "/^privilege_token/c\privilege_token = ${privilegetoken}" /home/frp/frps.ini
	systemctl restart supervisor

	echo -e "${Tip}当前 FRP 面板密码:${GreenFont} ${dashboardpwd} ${FontEnd}"
	echo -e "${Tip}当前 FRP 访问命牌:${GreenFont} ${privilegetoken} ${FontEnd}"
}

function do_sshkeys()
{
	username=`whoami`
	if [ "${username}" == "root" ]; then
		echo -e "${Tip}请在非ROOT用户环境下执行！" && exit 1
	fi

	stty erase '^H' && read -p "请输入 ${username} 的密码:" userpwd
	if [ ! -z "${userpwd}" ]; then
		echo ${userpwd} | sudo -S apt-get update

		#rm -f ~/.ssh/known_hosts
		#address=`curl -sS --connect-timeout 10 -m 60 ${ipaddr_url}`
		#sshPort=`cat /etc/ssh/sshd_config | grep 'Port ' | grep -oE [0-9] | tr -d '\n'`
		#echo 'yes' | ${fsudo} ssh root@${address} -p ${sshPort} 
		mkdir ~/.ssh

		if [ -d ~/.ssh ]; then
			echo -e "${Tip}正在配置 SSH 授权密钥环境..."

			rm -f ~/.ssh/authorized_keys
			wget -N --no-check-certificate -q -O ~/.ssh/authorized_keys https://raw.githubusercontent.com/programs/scripts/master/vps/config/authorized_keys
			
			${fsudo} chmod 400 ~/.ssh/authorized_keys
			${fsudo} chattr +i ~/.ssh/authorized_keys
			${fsudo} chattr +i ~/.ssh

			#PasswordAuthentication yes
			${fsudo} sed -i "/^PasswordAuthentication/c\PasswordAuthentication no " /etc/ssh/sshd_config
			${fsudo} service sshd restart

			echo -e "${Info}成功为${GreenFont} ${username} ${FontEnd}设置 SSH 授权密钥."
		else
			echo -e "${Error}为${GreenFont} ${username} ${FontEnd}设置 SSH 授权密钥失败."
		fi
	else
		echo -e "${Error}不允许输入的空密码!" && exit 1
	fi
}

function do_bansshkey()
{
	username=`whoami`
	if [ "${username}" == "root" ]; then
		echo -e "${Tip}请在非ROOT用户环境下执行！" && exit 1
	fi

	stty erase '^H' && read -p "请输入 ${username} 的密码:" userpwd
	if [ ! -z "${userpwd}" ]; then
		echo ${userpwd} | sudo -S apt-get update

		${fsudo} sed -i "/^PasswordAuthentication/c\PasswordAuthentication yes" /etc/ssh/sshd_config
		${fsudo} service sshd restart
		echo -e "${Info}允许 SSH 登陆不使用授权密钥."

	else
		echo -e "${Error}不允许输入的空密码!" && exit 1
	fi
}

function do_enableipv6()
{
	stty erase '^H' && read -p "是否禁用 IPv6 ? [y/N] :" yn
	[[ -z "${yn}" ]] && yn="n"
	if [[ $yn == [Yy] ]]; then

echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" | tee /etc/sysctl.d/99-ubuntu-ipv6.conf
		service procps reload
		echo -e "${Tip}已禁用 IPv6."
		
	else
		rm -f /etc/sysctl.d/99-ubuntu-ipv6.conf
		service procps reload
		echo -e "${Tip}已删除 IPv6 的禁用!"
	fi
}

function do_nodequery()
{
	stty erase '^H' && read -p "请输入 NodeQuery 分配的令牌密码:" nodetoken
	if [ ! -z "${nodetoken}" ]; then

		nq_file='/home/bin/nq-install.sh'
		rm -f ${nq_file}
		wget -N --no-check-certificate -q -O ${nq_file} ${nodequery_url} && bash ${nq_file} ${nodetoken}

		echo -e "${Info}为本地成功分配 NodeQuery."

	else
		echo -e "${Error}不允许输入的空令牌密码!" && exit 1
	fi
}

function do_removenq()
{
	stty erase '^H' && read -p "是否确定移除 NodeQuery? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then

		rm -R /etc/nodequery && (crontab -u nodequery -l | grep -v "/etc/nodequery/nq-agent.sh") | crontab -u nodequery - && userdel nodequery
		echo -e "${Info}成功移除 NodeQuery.${GreenFont}(重启之后生效)${FontEnd}"
	fi
}

function do_uninsdocker()
{
	if [ ! -f /usr/bin/docker ]; then
		echo -e "${Info}已移除 Docker!" && exit 1
	fi

	stty erase '^H' && read -p "正在移除之前已安装的 Docker 版本，请确定? [Y/n]:" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then

		${fsudo} systemctl stop docker
		${fsudo} systemctl disable docker
		stty erase '^H' && read -p "是否保留原有的 Docker 镜像或容器? [Y/n]:" ynt
		[[ -z "${ynt}" ]] && ynt="y"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} sudo apt-get purge docker-ce
		else
			${fsudo} apt-get remove docker docker-engine docker.io
			${fsudo} rm -rf /var/lib/docker
		fi
		echo -e "${Info}已移除 Docker!"
	fi
}

function do_makedocker()
{
	if [ "$is64bit" != '64' ]; then
		echo -e "${Error}请使用64位系统安装 Docker!" && exit 1
	fi

	if [ -f /usr/bin/docker ]; then
		stty erase '^H' && read -p "继续之前 将先移除之前可能已安装的 Docker 版本，请确定? [Y/n]:" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then

			${fsudo} systemctl stop docker
			${fsudo} systemctl disable docker
			stty erase '^H' && read -p "是否保留原有的 Docker 镜像或容器? [Y/n]:" ynt
			[[ -z "${ynt}" ]] && ynt="y"
			if [[ $ynt == [Yy] ]]; then
				${fsudo} sudo apt-get purge docker-ce
			else
				${fsudo} apt-get remove -y docker docker-engine docker.io
				${fsudo} rm -rf /var/lib/docker
			fi
		else
			echo -e "${Error}暂时无法安装 Docker!" && exit 1
		fi
	fi
	
	#https://www.howtoing.com/ubuntu-docker
	${fsudo} apt-get update
	${fsudo} apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl software-properties-common

	#SET UP THE REPOSITORY
	if [ ${release} != "debian" ]; then
		${fsudo} apt-get install -y --no-install-recommends gnupg2
		curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
	fi
	if [ ${release} != "ubuntu" ]; then
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
	fi
	${fsudo} apt-key fingerprint 0EBFCD88

	if [ ${release} != "debian" ]; then
		${fsudo} add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	fi
	if [ ${release} != "ubuntu" ]; then
		${fsudo} add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
	fi
		
	#INSTALL DOCKER CE
	${fsudo} apt-get install -y docker.io #docker-ce docker-engine
		
	#设置权限
	dockeruser=${defaultuser}
	${fsudo} groupadd docker
	${fsudo} usermod -aG docker ${dockeruser}

	# https://github.com/docker/compose/releases
	${fsudo} rm -f /usr/local/bin/docker-compose
	${fsudo} curl -fsSL https://github.com/docker/compose/releases/download/1.23.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	${fsudo} chmod +x /usr/local/bin/docker-compose

	stty erase '^H' && read -p "是否设置国内镜像加速? [y/N]:" ynn
	[[ -z "${ynn}" ]] && ynn="n"
	if [[ $ynn == [Yy] ]]; then
		#设置镜像加速
		${fsudo} mkdir -p /etc/docker
		${fsudo} tee /etc/docker/daemon.json <<-'EOF'
		{
		"registry-mirrors": ["https://registry.docker-cn.com"]
		}
		EOF
	fi
	${fsudo} systemctl enable docker
	${fsudo} systemctl daemon-reload
	${fsudo} systemctl restart docker

	curl -fsSL https://get.docker.com -o /home/bin/get-docker.sh
	#${fsudo} bash /home/bin/get-docker.sh

	${fsudo} docker run hello-world
	${fsudo} docker rm `${fsudo} docker ps -a |awk '{print $1}' | grep [0-9a-z]` 
	${fsudo} docker rmi hello-world
	echo -e "${Info}已完成 DOCKER 运行环境的配置!"
}

function do_lnmpsite()
{
	if [ ! -f /usr/bin/docker ]; then
		echo -e "${Error}请先安装 Docker 运行环境!" && exit 1
	fi

	echo -e "${Info}正在部署 LNMP 网站 (DOCKER环境) ..."
	${fsudo} apt-get update
	${fsudo} apt-get install -y --no-install-recommends git

	currpath=`pwd`
	if [ -d /home/www ]; then
		stty erase '^H' && read -p "发现本地已存在 LNMP 站点，是否进行备份? [Y/n]:" yn
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			${fsudo} mkdir -p /home/backsite
			${fsudo} tar zcvf /home/backsite/www`date +%Y%m%d.%H%M%S`.tar.gz /home/www
			${fsudo} rm -rf /home/www
		fi
	fi

	if [ -d /home/www ]; then
		stty erase '^H' && read -p "在不备份的情况下是否删除原有 LNMP 站点并重新部署? [y/N]:" ynt
		[[ -z "${ynt}" ]] && ynt="n"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} rm -rf /home/www
		fi
	fi

	if [ ! -d /home/www ]; then
		cd /home
		${fsudo} git clone https://github.com/gorouter/lnmpsite.git
		${fsudo} mv /home/lnmpsite  /home/www
		${fsudo} chmod +x /home/www/lnmpsite
		${fsudo} ln -s /home/www/lnmpsite /usr/bin/lnmpsite
	fi

	if [ -f /home/www/docker-compose.yml ]; then

		if [ ! -f /home/www/mysql/.passwd ]; then

			dbdefpwd=`cat /dev/urandom | head -n 12 | md5sum | head -c 12`
			echo -e "${Tip}请设置 MySQL 数据库 Root 密码"
			stty erase '^H' && read -p "(回车，默认密码为 ${dbdefpwd}):" dbpasswd
			[[ -z "${dbpasswd}" ]] && dbpasswd=${dbdefpwd}

			# 生成安全数据
			/home/www/lnmpsite down > /dev/null 2>&1
			mysqldb=`cat /home/www/docker-compose.yml | grep lnmpsite-mysql | awk -F 'image:' '{print $2}'`
			datamap='/home/www/mysql/data:/var/lib/mysql'
			confmap='/home/www/mysql/my.cnf:/etc/my.cnf'
			docker run -d --name semysql -p 3306:3306 -v ${datamap} -v ${confmap} -e MYSQL_ROOT_PASSWORD=${dbpasswd} ${mysqldb}
			echo -e "${Tip}正在初始化数据库，请稍等 ... "
			sleep 10s
			docker exec semysql bash -c "/usr/local/bin/wpsinit"
			sleep 2s
			docker stop semysql > /dev/null 2>&1 && docker rm semysql > /dev/null 2>&1
			echo -e "${Tip}请牢记此数据库 ROOT 密码:${GreenFont} ${dbpasswd} ${FontEnd}"

			# 生成无效密码信息
			dbngpwd=`cat /dev/urandom | head -n 32 | md5sum | head -c 32`
			config="MySQLpwd=${dbngpwd}"
			templ=`cat /home/www/docker-compose.yml`
			printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/www/docker-compose.yml
			touch /home/www/mysql/.passwd
		fi

		cd /home/www
		/home/www/lnmpsite up
		#docker logs mysql
	fi

	cd ${currpath}
	echo -e "${Info}LNMP 网站部署完成."
}

function do_update()
{
	rm -f /usr/bin/vps && wget -N --no-check-certificate -q -O /usr/bin/vps https://raw.githubusercontent.com/programs/scripts/master/vps/setup.sh && chmod +x /usr/bin/vps && clear && vps
	echo -e "${Info}更新程序到最新版本 完成!"
}

#主程序入口
echo -e "${GreenFont}
+-----------------------------------------------------
| VPS Script 1.x FOR Ubuntu/Debian
+-----------------------------------------------------
| Copyright © 2015-2018 programs All rights reserved.
+-----------------------------------------------------
${FontEnd}"

checkSystem
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
action=$1
[[ -z $1 ]] && action=help
case "$action" in
	install | redoswap | update | speedtest | lnmpsite | bbrstatus | ssrstatus | sysupgrade | adduser | deluser | ssrmu | uninsdocker | iptable | configssh | qsecurity | editfrp | frpsecurity | enableipv6 | makedocker | nodequery | removenq)
	checkRoot
	do_${action}
	;;
	sshkeys)
	do_sshkeys
	;;
	bansshkey)
	do_bansshkey
	;;
	*)
	echo " "
	echo -e "用法: ${GreenFont}${0##*/}${FontEnd} [指令]"
	echo "指令:"
	echo "    install    -- 安装并初始化VPS环境"
	echo "    update     -- 更新程序到最新版本"
	echo "    makedocker -- 生成 DOCKER 运行环境"
	echo "    redoswap   -- 创建或重建交换分区"
	echo "    lnmpsite   -- 部署 LNMP 网站 (DOCKER环境)"
	echo "    uninsdocker-- 移除 DOCKER 运行环境"
	echo "    speedtest  -- 测试网络速度"
	echo "    bbrstatus  -- 查看 BBR 状态"
	echo "    ssrstatus  -- 查看 SSR 状态"
	echo "    ssrmu      -- 运行 SSR 修改或增加配置"
	echo "    sysupgrade -- 系统更新"
	echo "    adduser    -- 新增用户"
	echo "    deluser    -- 删除用户"
	echo "    iptable    -- 修改防火墙"
	echo "    configssh  -- 修改 SSH 配置"
	echo "    qsecurity  -- 查询本地安全信息"
	echo "    editfrp    -- 修改 FRP 配置"
	echo "    frpsecurity-- 修改 FRP 面板密码及令牌"
	echo "    enableipv6 -- 开关 IPv6"
	echo "    nodequery  -- 增加 nodequery 监控"
	echo "    removenq   -- 移除 nodequery 监控"
	echo "    sshkeys    -- 配置 SSH 登陆使用授权密钥 (须非ROOT用户环境)"
	echo "    bansshkey  -- 允许 SSH 登陆不使用授权密钥 (须非ROOT用户环境)"
	echo " "
	;;
esac
