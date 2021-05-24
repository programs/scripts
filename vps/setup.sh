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
doinstall='false'

# 第三方URL定义
url_ssrmu='https://raw.githubusercontent.com/ToyoDAdoubiBackup/doubi/master/ssrmu.sh'
url_zbanch='https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh'
url_sbanch='https://raw.githubusercontent.com/oooldking/script/master/superbench.sh'
url_ipaddr='https://www.bt.cn/Api/getIpAddress'
url_nodequery='https://raw.github.com/nodequery/nq-agent/master/nq-install.sh'
url_v2ray='https://233blog.com/v2ray.sh'
url_speeder='xiaofd.github.io/ruisu.sh'
url_speederall='https://github.com/chiakge/Linux-NetSpeed/raw/master/tcp.sh'
url_wordpress='https://cn.wordpress.org/wordpress-'
url_wplasten='https://wordpress.org/latest.tar.gz'
url_frpaddr='https://github.com/fatedier/frp/releases/download/'

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

		apt-get update

		locale-gen en_US.UTF-8
		dpkg-reconfigure locales

		rm -rf /etc/localtime
		ln -s /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime 

		defaultpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 16`
		echo -e "${Info}请修改ROOT密码"
		stty erase '^H' && read -p "(回车，默认密码为 ${defaultpwd}):" rootpasswd && stty erase '^?' 
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

function createUser()
{
	echo -e "${Info}请输入 将要创建的用户名"
	stty erase '^H' && read -p "(回车，默认用户名为 ${defaultuser}):" username && stty erase '^?' 
	[[ -z "${username}" ]] && username=${defaultuser}

	exist_user=`cat /etc/passwd | grep ${username} | awk -F ':' '{print $1}'`
	if [ -z "${exist_user}" ]; then

		useradd -d "/home/${username}" -m -s "/bin/bash" ${username}

		userdefpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 16`
		echo -e "${Info}请输入 用户对应的密码"
		stty erase '^H' && read -p "(回车，默认密码为 ${userdefpwd}):" userpasswd && stty erase '^?' 
		[[ -z "${userpasswd}" ]] && userpasswd=${userdefpwd}
		#echo "${userpasswd}" | passwd ${username} --stdin > /dev/null 2>&1
		echo ${username}:${userpasswd} | chpasswd

		usermod -aG sudo ${username}
		echo "export PATH=$PATH:/home/bin" >> /home/${username}/.bashrc

	else
		echo -e "${Tip}要创建的用户名${GreenBack} ${username} ${FontEnd}已经存在"
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
		if [ ! -z "${tmpswapfile}" ]; then

			echo -e "${Info}正在移除原有交换分区..."
			[[ -f ${tmpswapfile} ]] && swapoff ${tmpswapfile} > /dev/null 2>&1
			sleep 2s
			[[ -f ${tmpswapfile} ]] && rm -f ${tmpswapfile}

			delSwapfile=`echo ${tmpswapfile} | sed 's#\/#\\\/#g'`
			[[ ! -z "${delSwapfile}" ]] && sed -i "/${delSwapfile}/d" /etc/fstab
		fi
		need_swap='do'
	else
		echo -e "${Info}当前系统交换分区已存在，大小为${GreenFont} ${swap_size}M ${FontEnd}"

		swap_file=`swapon -s | grep -v 'Filename' | grep -v 'dev' | awk '{print $1}'`
		if [ ! -z "${swap_file}" ] && [ -f ${swap_file} ]; then
			stty erase '^H' && read -p "是否重新创建交换分区? [Y/n] :" ynt && stty erase '^?' 
			[[ -z "${ynt}" ]] && ynt="y"
			if [[ $ynt == [Yy] ]]; then
				swapfile=${swap_file}

				echo -e "${Info}正在移除原有交换分区..."
				[[ -f ${swap_file} ]] && swapoff ${swap_file} > /dev/null 2>&1
				sleep 2s
				[[ -f ${swap_file} ]] && rm -f ${swap_file}

				delSwapfile=`echo ${swap_file} | sed 's#\/#\\\/#g'`
				[[ ! -z "${delSwapfile}" ]] && sed -i "/${delSwapfile}/d" /etc/fstab
				need_swap='do'
			fi
		fi
	fi

	if [ "x${need_swap}" == "xdo" ]; then
		
		echo -e "${Info}当前物理内存为${GreenBack} ${tram_size}M ${FontEnd}"
		stty erase '^H' && read -p "请输入将要创建交换分区大小 (默认等于物理内存-100M) :" inputsize && stty erase '^?' 
		[[ -z "${inputsize}" ]] && inputsize=`expr ${tram_size} - 100`
		dd if=/dev/zero of=${swapfile} bs=${inputsize}M count=1

		swapsize=0
		[[ ! -z "${swapfile}" ]] && swapsize=`du -b ${swapfile} | awk '{print $1}'`
		if [ ! ${swapsize} -eq 0 ]; then

			chmod 600 ${swapfile}
			mkswap ${swapfile} > /dev/null 2>&1
			swapon ${swapfile} > /dev/null 2>&1
			echo "${swapfile}    swap    swap    defaults    0 0" >> /etc/fstab

			swap_size=$( free -m | awk '/Swap/ {print $2}' )
			swapon -s
			echo -e "${Info}创建交换分区完成，实际大小为${GreenFont} ${swap_size}M ${FontEnd}"
		else
			echo -e "${Error}创建交换分区失败!"

			if [ "${doinstall}" == "true" ]; then 
				stty erase '^H' && read -p "是否继续? [y/N]:" yn && stty erase '^?' 
				[[ -z "${yn}" ]] && yn="n"
				if [[ $yn == [Yy] ]]; then
					echo -e "${Info}本程序被中止!"
					exit 1
				fi
			fi
		fi
	fi
}

function updateSystem()
{
	apt-get update > /dev/null 2>&1
	
	stty erase '^H' && read -p "是否需要更新系统 ? [y/N] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="n"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info}正在更新系统..."
		apt-get upgrade -y
		echo -e "${Info}更新系统完成."
	fi
}

function installddos()
{
	if [ -d '/usr/local/ddos' ]; then
		echo -e "${Tip}DDOS 已经安装，若要重新安装请首先卸载之前的 DDOS 版本."
	else
		mkdir /usr/local/ddos

		echo -e "${Info}正在安装 DDOS";
		[[ -f /usr/local/ddos/ddos.conf ]] && rm -f /usr/local/ddos/ddos.conf 
		[[ -f /usr/local/ddos/ignore.ip.list ]] && rm -f /usr/local/ddos/ignore.ip.list
		[[ -f /usr/local/ddos/ddos.sh ]] && rm -f /usr/local/ddos/ddos.sh

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

function do_ssripv6()
{
	if [ ! -f /etc/init.d/ssrmu ]; then
		echo -e "${Error}检测到未安装 SSR，请安装之后再试!" && exit 1
	fi

	apt-get install -y --no-install-recommends jq
	stty erase '^H' && read -p "SSR 是否使用 IPv6 配置? [Y/n] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		ipv6flag='true'
		[[ -f /etc/sysctl.d/99-ubuntu-ipv6.conf ]] && mv /etc/sysctl.d/99-ubuntu-ipv6.conf /etc/sysctl.d/99-ubuntu-ipv6
	else
		ipv6flag='false'
		[[ -f /etc/sysctl.d/99-ubuntu-ipv6 ]] && mv /etc/sysctl.d/99-ubuntu-ipv6 /etc/sysctl.d/99-ubuntu-ipv6.conf
	fi

	userconfig='/usr/local/shadowsocksr/user-config.json'
	echo -e "${Info} Path ${GreenFont}${userconfig}${FontEnd}"
	usercontent=`cat ${userconfig} | \
		jq 'to_entries | \
			map(if .key == "dns_ipv6" \
				then . + {"value":'${ipv6flag}'} \
				else . \
				end \
				) | \
			from_entries'`
	echo ${usercontent} > ${userconfig}
	PID=`ps -ef |grep -v grep | grep server.py |awk '{print $2}'`
    [[ ! -z ${PID} ]] && /etc/init.d/ssrmu stop
    /etc/init.d/ssrmu start
	service procps reload
	echo -e "${Info}已完成 SSR IPv6 配置!"
}

function do_ssrmdport()
{
	if [ ! -f /etc/init.d/ssrmu ]; then
		echo -e "${Error}检测到未安装 SSR，请安装之后再试!" && exit 1
	fi

	apt-get install -y --no-install-recommends jq
	userconfig='/usr/local/shadowsocksr/user-config.json'

	ssrmdport='do'
	stty erase '^H' && read -p "请输入 SSR 的端口号? (回车，单用户情况可自动获取):" ssr_port && stty erase '^?' 
	if [ -z "${ssr_port}" ]; then
		count=`python /usr/local/shadowsocksr/mujson_mgr.py -l | wc -l`
		if [ ${count} -eq 1 ]; then
			ssr_port=`python /usr/local/shadowsocksr/mujson_mgr.py -l | grep port | awk '{print $4}'`
		else
			echo -e "${Tip}当前 SSR 存在多用户，暂不支持设置端口，请手动设置否则可能无法使用！"
			echo -e "${Tip}默认设置为${GreenBack} 80 ${FontEnd}端口，如果设置了与此不同的端口，请手动修正！"
			echo -e "${Tip}  1. 修改 ${userconfig} -> 中的${GreenFont} server_port${FontEnd};"
			echo -e "${Tip}  2. 修改 ${userconfig} -> 中的${GreenFont} redirect${FontEnd};"
			echo -e "${Tip}  3. 修改 iptable 防火墙对应端口."
			ssrmdport=''
		fi
	fi

	if [ "x${ssrmdport}" == "xdo" ]; then

		redirect="[ \"*:${ssr_port}#127.0.0.1:8070\" ]"
		echo -e "${Info} Path ${GreenFont}${userconfig}${FontEnd}"
		usercontent=`cat ${userconfig} | \
			jq 'to_entries | \
				map(if .key == "server_port" \
					then . + {"value":'${ssr_port}'} \
					else . \
					end \
					if .key == "redirect" \
					then . + {"value":'${redirect}'}
					else . \
					end
					) | \
				from_entries'`
		echo ${usercontent} > ${userconfig}

		#iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
		#iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ssr_port} -j ACCEPT
		iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ssr_port} -j ACCEPT
		iptables-save > /etc/iptables.up.rules
		#iptables-restore < /etc/iptables.up.rules

		echo -e "${Info}已完成 SSR 端口配置!"
	fi
}

function setupSsrmu()
{
	if [ ! -s /usr/local/shadowsocksr/user-config.json ]; then
		echo -e "${Info}正在安装 SSR (默认配置为${GreenBack} 80 ${FontEnd}端口) ..."
		[[ -f /home/bin/ssrmu.sh ]] && rm -f /home/bin/ssrmu.sh
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh ${url_ssrmu}
		chmod +x /home/bin/ssrmu.sh
		/home/bin/ssrmu.sh

		sleep 1s
		[[ -f /usr/local/shadowsocksr/user-config.json ]] && rm -f /usr/local/shadowsocksr/user-config.json
		wget -N --no-check-certificate -q -O /usr/local/shadowsocksr/user-config.json https://raw.githubusercontent.com/programs/scripts/master/vps/config/user-config.json

		do_ssrmdport
		do_ssripv6
		echo -e "${Info}SSR 已完成安装."
	else
		echo -e "${Info}SSR 已安装."
	fi
}

function installFrp()
{
	echo -e "${Info}正在安装 FRP ..."

	apt-get install -y --no-install-recommends supervisor
	if [ ! -d /home/frp ]; then
		mkdir -p /home/frp
	fi

	[[ -f /home/frp/frps ]] && rm -f /home/frp/frps
	[[ -f /home/frp/frpstart ]] && rm -f /home/frp/frpstart
	[[ -f /home/frp/frps.ini ]] && rm -f /home/frp/frps.ini

	frpdefault=''
	stty erase '^H' && read -p "请输入要安装的 FRP 版本? (格式为x.x.x，如: 0.21.0，SSR 可直接回车):" frpversion && stty erase '^?' 
	if [ ! -z "${frpversion}" ]; then

		[[ -f /tmp/frp_${frpversion}_linux_amd64.tar.gz ]] && rm -f /tmp/frp_${frpversion}_linux_amd64.tar.gz
		#https://github.com/fatedier/frp/releases/download/v0.21.0/frp_0.21.0_linux_amd64.tar.gz
		wget -N --no-check-certificate -q -O /tmp/frp_${frpversion}_linux_amd64.tar.gz ${url_frpaddr}v${frpversion}/frp_${frpversion}_linux_amd64.tar.gz
		
		if [ -f /tmp/frp_${frpversion}_linux_amd64.tar.gz ]; then
			tar -C /home/frp/ -xzvf /tmp/frp_${frpversion}_linux_amd64.tar.gz > /dev/null 2>&1
			mv /home/frp/frp_${frpversion}_linux_amd64/* /home/frp
			rm -rf /home/frp/frp_${frpversion}_linux_amd64
			rm -f /tmp/frp_${frpversion}_linux_amd64.tar.gz
			[[ -f /home/frp/frps.ini ]] && rm -f /home/frp/frps.ini
			#rm -f /home/frp/frpc* /home/frp/LICENSE
		fi

		if [ ! -f /home/frp/frps ]; then
			echo -e "${Tip}未找到需要安装的版本，程序将按默认的处理，如需要安装指定版本，请重新执行安装指令！"
			frpdefault='default'
		fi

	else
		echo -e "${Tip}程序将按默认的处理，如需要安装指定版本，请重新执行安装指令！"
		frpdefault='default'
	fi

    if [ "${frpdefault}" == "default" ]; then
		wget -N --no-check-certificate -q -O /home/frp/frps https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps
	fi
	wget -N --no-check-certificate -q -O /home/frp/frps.ini https://raw.githubusercontent.com/programs/scripts/master/vps/frp/frps.ini
	if [ "${frpdefault}" != "default" ]; then
		sed -i "/^privilege_token/c\token = L1234567890=frp." /home/frp/frps.ini
	fi

	if [ -f /home/frp/frps.ini ] && [ -f /home/frp/frps ]; then

		chmod +x /home/frp/frps
		# 开启端口
		iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 7137 -j ACCEPT
		iptables -D INPUT -p udp -m state --state NEW -m udp --dport 7137:7138 -j ACCEPT
		iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 8000:9000 -j ACCEPT

		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 7137 -j ACCEPT
		iptables -I INPUT -p udp -m state --state NEW -m udp --dport 7137:7138 -j ACCEPT
		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 8000:9000 -j ACCEPT
		iptables-save > /etc/iptables.up.rules

		[[ -f /etc/supervisor/conf.d/frp.conf ]] && rm -f /etc/supervisor/conf.d/frp.conf
		wget -N --no-check-certificate -q -O /etc/supervisor/conf.d/frp.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/frp.conf
		systemctl restart supervisor
		sleep 1s
		supervisorctl status
		echo -e "${Info}FRP 安装完成."

		do_frpsecurity
	else
		echo -e "${Error}FRP 安装出错."
	fi 
}

function do_setupssr()
{
	# SSR && FRP
	stty erase '^H' && read -p "是否需要安装SSR 以及使用 FRP 于80端口隐藏? [Y/n]:" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		setupSsrmu
		installFrp
	fi
}

function do_setupvray()
{
	if [ ! -s /etc/v2ray/config.json ]; then

		echo -e "${Info}正在安装 V2Ray ..."
		[[ -f /home/bin/v2ray.sh ]] && rm -f /home/bin/v2ray.sh
		wget -N --no-check-certificate -q -O /home/bin/v2ray.sh ${url_v2ray}
		chmod +x /home/bin/v2ray.sh
		/home/bin/v2ray.sh

		echo -e "${Info}V2Ray 已完成安装."
	else
		echo -e "${Info}V2Ray 已安装."
		echo -e "${Info}如果需要重新安装，请执行命令${GreenFont} v2ray.sh ${FontEnd}"
	fi

	echo -e "${Info}${GreenFont}v2ray${FontEnd} 命令参考 --

v2ray info       查看 V2Ray 配置信息
v2ray config     修改 V2Ray 配置
v2ray link       生成 V2Ray 配置文件链接
v2ray infolink   生成 V2Ray 配置信息链接
v2ray qr         生成 V2Ray 配置二维码链接
v2ray ss         修改 Shadowsocks 配置
v2ray ssinfo     查看 Shadowsocks 配置信息
v2ray ssqr       生成 Shadowsocks 配置二维码链接
v2ray status     查看 V2Ray 运行状态
v2ray start      启动 V2Ray
v2ray stop       停止 V2Ray
v2ray restart    重启 V2Ray
v2ray log        查看 V2Ray 运行日志
v2ray update     更新 V2Ray
v2ray update.sh  更新 V2Ray 管理脚本
v2ray uninstall  卸载 V2Ray
"
}

function setupServices()
{
	sleep 1s
	echo -e "${Info}正在安装必要的系统软件..."
	apt-get install -y --no-install-recommends virt-what fail2ban ca-certificates iptables-persistent

	sleep 1s
	echo -e "${Info}正在下载源文件..."
	
	[[ -f /etc/ssh/sshd_config ]] && rm -f /etc/ssh/sshd_config
	[[ -f /etc/fail2ban/jail.conf ]] && rm -f /etc/fail2ban/jail.conf
	[[ -f /etc/iptables.up.rules ]] && rm -f /etc/iptables.up.rules

	wget -N --no-check-certificate -q -O /etc/ssh/sshd_config https://raw.githubusercontent.com/programs/scripts/master/vps/config/sshd_config
	wget -N --no-check-certificate -q -O /etc/fail2ban/jail.conf https://raw.githubusercontent.com/programs/scripts/master/vps/config/jail.conf
	wget -N --no-check-certificate -q -O /etc/iptables.up.rules https://raw.githubusercontent.com/programs/scripts/master/vps/config/iptables.up.rules

	service sshd restart
	service fail2ban restart
	fail2ban-client status
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
	doinstall='true'

	configRoot
	createUser
	createSwap
	updateSystem
	installddos
	setupServices
	do_setupssr
	setupBBR
}

function do_speedtest()
{
	apt-get update > /dev/null 2>&1
	apt-get install -y --no-install-recommends tcptraceroute bc
	wget -N --no-check-certificate -q -O /usr/bin/tcpping http://www.vdberg.org/~richard/tcpping
	chmod +x /usr/bin/tcpping

	[[ -f /home/bin/zbanch.sh ]] && rm -f /home/bin/zbanch.sh
	wget -N --no-check-certificate -q -O /home/bin/zbanch.sh ${url_zbanch}
	chmod +x /home/bin/zbanch.sh
	/home/bin/zbanch.sh

	[[ -f /home/bin/superbench.sh ]] && rm -f /home/bin/superbench.sh
	wget -N --no-check-certificate -q -O /home/bin/superbench.sh ${url_sbanch}
	chmod +x /home/bin/superbench.sh

	stty erase '^H' && read -p "是否需要进一步进行网络测试? [Y/n]:" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		mtr -rw www.baidu.com
		/home/bin/superbench.sh
	fi
}

function do_bbrstatus()
{
	if [ ! -f /home/bin/bbr.sh ]; then
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

	ipaddr=`curl -sS --connect-timeout 10 -m 60 ${url_ipaddr}`
	[[ -z "${ipaddr}" || "${ipaddr}" == "0.0.0.0" ]] && ipaddr=`curl -sS -4 icanhazip.com`
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
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh ${url_ssrmu}
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
	stty erase '^H' && read -p "(回车，默认用户名为 ${defaultuser}):" username && stty erase '^?' 
	[[ -z "${username}" ]] && username=${defaultuser}

	exist_user=`cat /etc/passwd | grep ${username} | awk -F ':' '{print $1}'`
	if [ ! -z "${exist_user}" ]; then

		echo -e "${RedFont}${Tip}删除用户 ${username} 将不可恢复!${FontEnd}"
		stty erase '^H' && read -p "请确认? [y/N]:" yn && stty erase '^?' 
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
	stty erase '^H' && read -p "是否使防火墙立即生效 ? [Y/n] :" yn && stty erase '^?' 
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

function do_configssh()
{
	sshPort=`cat /etc/ssh/sshd_config | grep 'Port ' | grep -oE [0-9] | tr -d '\n'`
	echo -e "${Info}当前 SSH 端口号:${GreenFont} ${sshPort} ${FontEnd}"

	stty erase '^H' && read -p "是否需要手动配置 SSH ? [Y/n] :" ynt && stty erase '^?' 
	[[ -z "${ynt}" ]] && ynt="y"
	if [[ $ynt == [Yy] ]]; then

		vim /etc/ssh/sshd_config
		stty erase '^H' && read -p "是否使SSH立即生效 ? [Y/n] :" yn && stty erase '^?' 
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

function do_setupfrp()
{
	installFrp
}

function do_editfrp()
{
	vim /home/frp/frps.ini
	stty erase '^H' && read -p "是否使FRP立即生效 ? [Y/n] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		systemctl restart supervisor
	fi
}

function do_frpsecurity()
{
	stty erase '^H' && read -p "是否需要设置 FRP 面板密码及其访问命牌? [Y/n] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		
		dashboardrand=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		stty erase '^H' && read -p "请输入 FRP 面板密码:" dashboardpwd && stty erase '^?' 
		[[ -z "${dashboardpwd}" ]] && dashboardpwd=${dashboardrand}

		privilegetokenrand=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		stty erase '^H' && read -p "请输入 FRP 访问命牌:" privilegetoken && stty erase '^?' 
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

function do_ensshkeys()
{
	username=`whoami`
	if [ "${username}" == "root" ]; then
		echo -e "${Tip}请在非ROOT用户环境下执行！" && exit 1
	fi

	stty erase '^H' && read -p "请输入 ${username} 的密码:" userpwd && stty erase '^?' 
	if [ ! -z "${userpwd}" ]; then
		echo ${userpwd} | sudo -S apt-get update

		#rm -f ~/.ssh/known_hosts
		#address=`curl -sS --connect-timeout 10 -m 60 ${url_ipaddr}`
		#sshPort=`cat /etc/ssh/sshd_config | grep 'Port ' | grep -oE [0-9] | tr -d '\n'`
		#echo 'yes' | ${fsudo} ssh root@${address} -p ${sshPort} 
		mkdir ~/.ssh

		if [ -d ~/.ssh ]; then
			echo -e "${Tip}正在配置 SSH 授权密钥环境..."

			[[ ~/.ssh/authorized_keys ]] && ${fsudo} rm -f ~/.ssh/authorized_keys
			${fsudo} wget -N --no-check-certificate -q -O ~/.ssh/authorized_keys https://raw.githubusercontent.com/programs/scripts/master/vps/config/authorized_keys
			
			${fsudo} chmod 400 ~/.ssh/authorized_keys
			${fsudo} chown ${username}:${username} ~/.ssh/authorized_keys
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

	stty erase '^H' && read -p "请输入 ${username} 的密码:" userpwd && stty erase '^?' 
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
	stty erase '^H' && read -p "是否禁用 IPv6 ? [y/N] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="n"
	if [[ $yn == [Yy] ]]; then

echo "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" | tee /etc/sysctl.d/99-ubuntu-ipv6.conf
		service procps reload
		echo -e "${Tip}系统已禁用 IPv6."
		
	else
		[[ -f /etc/sysctl.d/99-ubuntu-ipv6.conf ]] && rm -f /etc/sysctl.d/99-ubuntu-ipv6.conf
		service procps reload
		echo -e "${Tip}系统已启用 IPv6 !"
	fi
}

function do_nodequery()
{
	stty erase '^H' && read -p "请输入 NodeQuery 分配的令牌密码:" nodetoken && stty erase '^?' 
	if [ ! -z "${nodetoken}" ]; then

		nq_file='/home/bin/nq-install.sh'
		rm -f ${nq_file}
		wget -N --no-check-certificate -q -O ${nq_file} ${url_nodequery} && bash ${nq_file} ${nodetoken}

		echo -e "${Info}为本地成功分配 NodeQuery."

	else
		echo -e "${Error}不允许输入的空令牌密码!" && exit 1
	fi
}

function do_removenq()
{
	stty erase '^H' && read -p "是否确定移除 NodeQuery? [Y/n] :" yn && stty erase '^?' 
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

	stty erase '^H' && read -p "正在移除之前已安装的 Docker 版本，请确定? [Y/n]:" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then

		${fsudo} systemctl stop docker
		${fsudo} systemctl disable docker
		stty erase '^H' && read -p "是否保留原有的 Docker 镜像或容器? [Y/n]:" ynt && stty erase '^?' 
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
		stty erase '^H' && read -p "继续之前 将先移除之前可能已安装的 Docker 版本，请确定? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then

			${fsudo} systemctl stop docker
			${fsudo} systemctl disable docker
			stty erase '^H' && read -p "是否保留原有的 Docker 镜像或容器? [Y/n]:" ynt && stty erase '^?' 
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
	[[ -f /usr/local/bin/docker-compose ]] && ${fsudo} rm -f /usr/local/bin/docker-compose
	${fsudo} curl -L https://github.com/docker/compose/releases/download/1.29.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	${fsudo} chmod +x /usr/local/bin/docker-compose

	stty erase '^H' && read -p "是否设置国内镜像加速? [y/N]:" ynn && stty erase '^?' 
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

function checkdocker()
{
	if [ ! -f /usr/bin/docker ]; then
		echo -e "${Error}请先安装 Docker 运行环境!" && exit 1
	fi

	${fsudo} apt-get update
	${fsudo} apt-get install -y --no-install-recommends git
}

function do_vrayworld()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 V2Ray 环境 ..."

	currpath=`pwd`
	if [ -d /home/vraworld ]; then
		stty erase '^H' && read -p "发现本地已存在基于DOCKER的 V2Ray 环境，是否进行备份? [y/N]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="n"
		if [[ $yn == [Yy] ]]; then
			${fsudo} mkdir -p /home/backworld
			${fsudo} tar zcvf /home/backworld/vray`date +%Y%m%d.%H%M%S`.tar.gz /home/vraworld
			${fsudo} rm -rf /home/vraworld
		fi
	fi

	if [ -d /home/vraworld ]; then
		stty erase '^H' && read -p "在不备份的情况下是否删除原有 V2Ray 环境并重新部署? [Y/n]:" ynt && stty erase '^?' 
		[[ -z "${ynt}" ]] && ynt="y"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} rm -rf /home/vraworld
		fi
	fi

	if [ ! -d /home/vraworld ]; then
		cd /home
		${fsudo} git clone https://github.com/gorouter/zraypro.git
		${fsudo} mv /home/zraypro  /home/vraworld
		${fsudo} chmod +x /home/vraworld/zraypro
		${fsudo} ln -s /home/vraworld/zraypro /usr/bin/zraypro
	fi

	if [ -f /home/vraworld/docker-compose.yml ]; then

		if [ ! -f /home/vraworld/.passwd ]; then

			tmpuuid=$(cat /proc/sys/kernel/random/uuid)
			read -p "请输入UUID (默认为 ${tmpuuid}):" randuuid
			[[ -z "${randuuid}" ]] && randuuid=${tmpuuid}

			read -p "请输入alterid (默认为 32):" alterid 
			[[ -z "${alterid}" ]] && alterid=32

			if [ ! -f /home/vraworld/docker-compose-template.yml ]; then
				cp /home/vraworld/docker-compose.yml /home/vraworld/docker-compose-template.yml
			fi
			config=" \
UUID_p=${randuuid} \
ALTERID_p=${alterid}"
			templ=`cat /home/vraworld/docker-compose-template.yml`
			printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/vraworld/docker-compose.yml

			echo -e "${Tip}请牢记以下连接信息"
			echo -e "${Info}端口${GreenBack} 80|443 ${FontEnd}"
			echo -e "${Info}UUID${GreenBack} ${randuuid} ${FontEnd}"
			echo -e "${Info}alterid${GreenBack} ${alterid} ${FontEnd}"
			echo -e "${Info}协议${GreenBack} ws ${FontEnd}"
			echo -e "${Info}ws域名${GreenBack} www.redhat.com ${FontEnd}"
			echo -e "${Info}ws路径${GreenBack} /api/ ${FontEnd}"

			touch /home/vraworld/.passwd
		fi

		cd /home/vraworld
		docker-compose up
		echo -e "${Info}V2Ray 环境部署完成."
	else
		echo -e "${Info}V2Ray 环境部署失败，请检查！."
	fi
	cd ${currpath}
}

function do_mtproxy()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 MTProxy 代理 ..."

	read -p "请输入访问端口 (默认为 18240):" mtport
	[[ -z "${mtport}" ]] && mtport='18240'
    echo -e "${Tip}请牢记此端口号:${GreenFont} ${mtport} ${FontEnd}"

    enabled=`docker ps -a | grep telegrammessenger | wc -l`
	if [ ! ${enabled} -eq 0 ]; then
		stty erase '^H' && read -p "发现 MTProxy 已启动，需要停用并重新部署吗? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			containId=`docker ps -a | grep telegrammessenger | awk '{print $1}'`
			docker stop ${containId}
			docker rm ${containId}
		fi
	fi
	
    echo -e "${Info} 开始配置 MTProxy 代理......"
	iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport ${mtport} -j ACCEPT
	iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport ${mtport} -j ACCEPT
	iptables-save > /etc/iptables.up.rules

	docker run -d -p${mtport}:443 --name=mtproxy --restart=always -v proxy-config:/home/mtproxy telegrammessenger/proxy:latest
	sleep 5s
	docker logs mtproxy

	echo -e "${Info} MTProxy 代理配置完成."
}

function do_ssrworld()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 SSR 环境 ..."

	echo -e "${Tip}在 DOCKER 环境下运行 SSR 暂时无法支持 IPv6！"
	stty erase '^H' && read -p "是否继续部署? [Y/n]:" ynn && stty erase '^?' 
	[[ -z "${ynn}" ]] && ynn="y"
	if [[ $ynn == [Nn] ]]; then
		echo -e "${Info}部署基于DOCKER的 SSR 环境 被中止！" && exit 1
	fi

	currpath=`pwd`
	if [ -d /home/ssrworld ]; then
		stty erase '^H' && read -p "发现本地已存在基于DOCKER的 SSR 环境，是否进行备份? [y/N]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="n"
		if [[ $yn == [Yy] ]]; then
			${fsudo} mkdir -p /home/backworld
			${fsudo} tar zcvf /home/backworld/ssr`date +%Y%m%d.%H%M%S`.tar.gz /home/ssrworld
			${fsudo} rm -rf /home/ssrworld
		fi
	fi

	if [ -d /home/ssrworld ]; then
		stty erase '^H' && read -p "在不备份的情况下是否删除原有 SSR 环境并重新部署? [Y/n]:" ynt && stty erase '^?' 
		[[ -z "${ynt}" ]] && ynt="y"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} rm -rf /home/ssrworld
		fi
	fi

	if [ ! -d /home/ssrworld ]; then
		cd /home
		${fsudo} git clone https://github.com/gorouter/zeropro.git
		${fsudo} mv /home/zeropro  /home/ssrworld
	fi

	if [ -f /home/ssrworld/docker-compose.yml ]; then

		if [ ! -f /home/ssrworld/.passwd ]; then

			read -p "请输入访问端口 (默认为 80):" cfg_port
			[[ -z "${cfg_port}" ]] && cfg_port='80'

			tmppasswd=`cat /dev/urandom | head -n 12 | md5sum | head -c 12`
			read -p "请输入SSR密码 (默认为 ${tmppasswd}):" ssr_passwd
			[[ -z "${ssr_passwd}" ]] && ssr_passwd=${tmppasswd}

			read -p "请输入加密方式 (默认为 none):" ssr_chiper
			[[ -z "${ssr_chiper}" ]] && ssr_chiper='none'

			read -p "请输入加密协议 (默认为 auth_chain_a):" ssr_proto
			[[ -z "${ssr_proto}" ]] && ssr_proto='auth_chain_a'

			read -p "请输入混淆方式 (默认为 http_simple):" ssr_obfs
			[[ -z "${ssr_obfs}" ]] && ssr_obfs='http_simple'

			dashboardpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`
		    privilegetoken=`cat /dev/urandom | head -n 16 | md5sum | head -c 32`

			if [ ! -f /home/ssrworld/docker-compose-template.yml ]; then
				cp /home/ssrworld/docker-compose.yml /home/ssrworld/docker-compose-template.yml
			fi
			config=" \
UNIFIED_CFG_PORT_p=${cfg_port} \
SSRCFG_PASSWD_p=${ssr_passwd} \
SSRCFG_CIPHER_p=${ssr_chiper} \
SSRCFG_PROTOCOL_p=${ssr_proto} \
SSRCFG_OBFS_p=${ssr_obfs} \
FRP_TOKEN_KEYS_p=${privilegetoken} \
FRP_DASHBOARD_PASSWD_p=${dashboardpwd} "
			templ=`cat /home/ssrworld/docker-compose-template.yml`
			printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/ssrworld/docker-compose.yml

			touch /home/lnmpsite/mysql/.passwd
		fi

		cd /home/ssrworld
		docker-compose up
		echo -e "${Info}SSR 环境部署完成."
	else
		echo -e "${Info}SSR 环境部署失败，请检查！."
	fi
	cd ${currpath}
}

function do_wordpress()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 BLOG 站点 ..."

	currpath=`pwd`
	if [ ! -d /home/lnmpsite/nginx/www ]; then
		stty erase '^H' && read -p "发现本地未安装 LNMP 网站运行环境，是否进行安装? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			do_lnmpsite
		else
			echo -e "${Tip}BLOG 站点部署被中止!" && exit 1
		fi
	fi

	if [ -d /home/lnmpsite/nginx/www ]; then

		#https://cn.wordpress.org/wordpress-4.9.4-zh_CN.tar.gz

		stty erase '^H' && read -p "请输入将要安装的 Wordpress 中文稳定版本? (格式为x.x.x，默认为 4.9.4):" wpversion && stty erase '^?' 
		[[ -z "${wpversion}" ]] && wpversion='4.9.4'

		cd /home/lnmpsite
		[[ -f /tmp/wpstable.tar.gz ]] && rm -f /tmp/wpstable.tar.gz
		wget -N --no-check-certificate -q -O /tmp/wpstable.tar.gz ${url_wordpress}${wpversion}-zh_CN.tar.gz

		if [ -f /tmp/wpstable.tar.gz ]; then

			echo -e "${Info}正在处理，请稍等..."
			/home/lnmpsite/lnmpsite stop > /dev/null 2>&1

			cd /tmp/
			tar -C /home/lnmpsite/nginx -xzvf /tmp/wpstable.tar.gz > /dev/null 2>&1
			[[ -d /home/lnmpsite/nginx/www ]] && rm -rf /home/lnmpsite/nginx/www
			mv /home/lnmpsite/nginx/wordpress /home/lnmpsite/nginx/www

			mkdir -p /home/lnmpsite/nginx/www/wp-content/uploads
			mkdir -p /home/lnmpsite/nginx/www/wp-content/upgrade
			chmod 755 /home/lnmpsite/nginx/www
			find /home/lnmpsite/nginx/www -type d -exec chmod 755 {} \;
			find /home/lnmpsite/nginx/www -iname "*.php"  -exec chmod 644 {} \;
			#chmod 777 -R /home/lnmpsite/nginx/www/wp-content

			rm -rf /tmp/wpstable.tar.gz

			#du -h --max-depth=0 ./www
			/home/lnmpsite/lnmpsite start > /dev/null 2>&1
			sleep 2s
			docker exec nginx bash -c "chown -R nginx:nginx /usr/share/nginx/html"

			echo -e "${Info}BLOG 网站已部署完成，请访问域名 Wordpress 进行相关设置."

		else
			echo -e "${Tip}下载安装包失败！"
		fi
	fi

	cd ${currpath}
}

function do_wpupdate()
{
	if [ ! -f /home/lnmpsite/nginx/www/wp-config.php ]; then
		stty erase '^H' && read -p "发现本地未部署 BLOG 站点，是否进行安装? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			do_wordpress
		fi
	else
		currpath=`pwd`
		cd /home/lnmpsite

		[[ -f /tmp/wpstable.tar.gz ]] && rm -f /tmp/wpstable.tar.gz
		if [ ! -f /tmp/wpstable.tar.gz ]; then

			stty erase '^H' && read -p "是否升级到最新的英文版本? [y/N]:" yrn && stty erase '^?' 
			[[ -z "${yrn}" ]] && yrn='n'
			if [[ $yn == [Nn] ]]; then
				echo -e "${Tip}升级被中止！" && exit 1 
			fi
			wget -N --no-check-certificate -q -O /tmp/wpstable.tar.gz ${url_wplasten}
		fi

		if [ -f /tmp/wpstable.tar.gz ]; then

			echo -e "${Info}正在处理，请稍等..."
			/home/lnmpsite/lnmpsite stop > /dev/null 2>&1

			cd /tmp/
			cp /home/lnmpsite/nginx/www/wp-config.php /tmp/wp-config.php
			tar -C /tmp -xzvf /tmp/wpstable.tar.gz > /dev/null 2>&1
			[[ -d /tmp/wordpress/wp-content ]] && rm -rf /tmp/wordpress/wp-content
			cp -R /tmp/wordpress/* /home/lnmpsite/nginx/www
			cp /tmp/wp-config.php /home/lnmpsite/nginx/www/wp-config.php
			
			mkdir -p /home/lnmpsite/nginx/www/wp-content/uploads
			mkdir -p /home/lnmpsite/nginx/www/wp-content/upgrade
			chmod 755 /home/lnmpsite/nginx/www
			find /home/lnmpsite/nginx/www -type d -exec chmod 755 {} \;
			find /home/lnmpsite/nginx/www -iname "*.php"  -exec chmod 644 {} \;
			#chmod 777 -R /home/lnmpsite/nginx/www/wp-content

			rm -rf /tmp/wpstable.tar.gz /tmp/wp-config.php
			rm -rf /tmp/wordpress

			/home/lnmpsite/lnmpsite start > /dev/null 2>&1
			sleep 2s
			docker exec nginx bash -c "chown -R nginx:nginx /usr/share/nginx/html"

			echo -e "${Info}BLOG 网站升级完成，请访问域名${GreenFont} https://域名/wp-admin/upgrade.php ${FontEnd}进行相关设置."

		else
			echo -e "${Tip}下载升级包失败！"
		fi

		cd ${currpath}
	fi
}

function do_wpenable()
{
	wp_rootpath=''
	stty erase '^H' && read -p "请输入站点所在根目录: " wp_rootpath && stty erase '^?' 
	if [ -z "${wp_rootpath}" ] || [ ! -d ${wp_rootpath} ]; then
		echo -e "${Tip}无效站点目录！" && exit 1
	fi

    if [ -f ${wp_rootpath}/wp-config.php ]; then
	   chmod -R 777 ${wp_rootpath}
	   echo -e "${Tip}完成设置! 请记住: ${GreenFont}升级完WP后务必恢复原目录权限!${FontEnd} "
	else
	    echo -e "${Tip}无效站点目录！" && exit 1
	fi	
}

function do_wpdisable()
{
	wp_rootpath=''
	stty erase '^H' && read -p "请输入站点所在根目录: " wp_rootpath && stty erase '^?' 
	if [ -z "${wp_rootpath}" ] || [ ! -d ${wp_rootpath} ]; then
		echo -e "${Tip}无效站点目录！" && exit 1
	fi

	if [ -f ${wp_rootpath}/wp-config.php ]; then
	    chmod 755 ${wp_rootpath}
		find ${wp_rootpath} -type d -exec chmod 755 {} \;
		find ${wp_rootpath} -type f -exec chmod 644 {} \;
		chown -R 998:${defaultuser} ${wp_rootpath}
		chmod -R 777 ${wp_rootpath}/wp-content/uploads/
		chmod -R 777 ${wp_rootpath}/wp-content/upgrade/

		echo -e "${Tip}完成设置! "
	else
	    echo -e "${Tip}无效站点目录！" && exit 1
	fi	
}

function do_wpnewsite()
{
	echo -e "${Tip}此功能暂未实现，但可以手工操作布署新站点:"
	echo -e "${Info}1. /home/lnmpsite/nginx/conf.d 目录中加入 ${GreenFont}站点名.conf${FontEnd} 并加入配置(配置可参考主站)"
	echo -e "${Info}2. /home/lnmpsite/nginx 目录下创建目录为 ${GreenFont}站点名${FontEnd}"
	echo -e "${Info}3. 修改文件 /home/lnmpsite/docker-compose.yml "
	echo -e "${Info}   nginx段加入: ${GreenFont}- ./nginx/站点名:/usr/share/nginx/站点名${FontEnd} "
	echo -e "${Info}   php  段加入: ${GreenFont}- ./nginx/站点名:/usr/share/nginx/站点名${FontEnd} "
	echo -e "${Info}4. 进入mysql执行: ${GreenFont}mysql -uroot -p\$MYSQL_ROOT_PASSWORD -P3306 -e \"CREATE DATABASE 站点名\"${FontEnd} "
	echo -e "${Info}5. 将站点WP文件拷贝到目录 ${GreenFont}/home/lnmpsite/nginx/站点名, 并配置相应数据库${FontEnd} "
	echo -e "${Info}6. 执行下列命令设置权限: ${GreenFont}vps wpdisable ${FontEnd}"
	echo -e "${Info}7. 执行重启命令: ${GreenFont}lnmpsite down/up ${FontEnd}"
	echo -e "${Info}8. 最后执行: ${GreenFont}docker exec nginx bash -c \"chown -R nginx:nginx /usr/share/nginx/站点名\"${FontEnd}"
	echo -e "${Tip}除主站点外，本脚本不提供其它站点的WP更新!"
}

function do_wprestore()
{
	echo -e "${Info}此功能暂未实现" && exit 1
}

function do_wpbackup()
{
	checkdocker

	#用命令备份数据库并删除7天前的备份
	#data_dir="/path/to/save/data/"
	#docker exec mysql bash -c "mysqldump -uroot -p${dbpasswd} --all-databases > \"${data_dir}/data_`date +%Y%m%d`.sql\""
    #find ${data_dir} -mtime +7 -name 'data_[1-9].sql' -exec rm -rf {} \;

	currpath=`pwd`
	enabled=`docker ps -a | grep backup | wc -l`
	if [ ! ${enabled} -eq 0 ]; then
		stty erase '^H' && read -p "发现站点备份机制已启动，需要停用吗? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			cd /home/lnmpsite/backup
			docker-compose down
			rm -f /home/lnmpsite/backup/.passwd
			echo -e "${Info}站点备份机制已停用！如需要请重新执行此命令"
		fi
	else
		stty erase '^H' && read -p "发现站点备份机制未启动，需要启用吗? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then

			cd /home/lnmpsite/backup
			if [ -f /home/lnmpsite/backup/docker-compose.yml ]; then

				echo -e "${Info}正在为基于DOCKER的 BLOG 站点启用备份机制 ..."
				if [ ! -f /home/lnmpsite/backup/.passwd ]; then

					docker-compose down > /dev/null 2>&1

					datamap='/home/lnmpsite:/home/site'
					backupmap='/home/lnmpback:/home/backup'
					doit='do' && Apikey='none' && Email='none' && Password='none'
					Secret_id='none' && Secret_key='none' && Region='none' && Bucketname='none'
					Tcuserid='none' && Tcpasswd='none' && Tcdevaddr='none'

					echo -e "${Info}目前支持的站点备份方式如下，请选择合适的进行备份:"
					echo -e "    1. 备份到腾讯云COS"
					echo -e "    2. 备份到Ge.tt"
					echo -e "    3. 备份到TeraCloud"
					echo -e ""
					stty erase '^H' && read -p "请选择以上备份试 (填数字选项):" selected && stty erase '^?' 
					[[ -z "${selected}" ]] && selected=0
					case "$selected" in
						1)
						read -p "请输入Secret Id: " Secret_id
						[[ -z "${Secret_id}" ]] && Secret_id='none'

						read -p "请输入Secret Key: " Secret_key
						[[ -z "${Secret_key}" ]] && Secret_key='none'

						read -p "请输入Region: " Region
						[[ -z "${Region}" ]] && Region='none'

						read -p "请输入Bucket name: " Bucketname
						[[ -z "${Bucketname}" ]] && Bucketname='none'
						;;

						2)
						read -p "请输入Api Key: " Apikey
						[[ -z "${Apikey}" ]] && Apikey='none'

						read -p "请输入Email: " Email
						[[ -z "${Email}" ]] && Email='none'

						read -p "请输入Password: " Password
						[[ -z "${Password}" ]] && Password='none'
						;;

						3)
						read -p "请输入User Id: " Tcuserid
						[[ -z "${Tcuserid}" ]] && Tcuserid='none'

						read -p "请输入Password: " Tcpasswd
						[[ -z "${Tcpasswd}" ]] && Tcpasswd='none'

						read -p "请输入WebDAV地址: " Tcdevaddr
						[[ -z "${Tcdevaddr}" ]] && Tcdevaddr='none'
						;;

						*)
						doit=''
						echo -e "${Tip}输入有误，无法处理，需要的请重试！" && exit 1
						;;
					esac

					if [ "x${doit}" == "xdo" ]; then

						echo -e "${Tip}正在初始化，请稍等 ... "
						#backupsrv=`cat /home/lnmpsite/backup/docker-compose.yml | grep lnmpsite-backup | awk -F 'image:' '{print $2}'`
						#docker run -d --name sebackup -v ${datamap} -v ${backupmap} -e tcdevaddr=${Tcdevaddr} -e tcpasswd=${Tcpasswd} -e tcuserid=${Tcuserid} -e apikey=${Apikey} -e email=${Email} -e password=${Password} -e secret_id=${Secret_id} -e secret_key=${Secret_key} -e region=${Region} -e bucketname=${Bucketname} ${backupsrv}
						#sleep 5s
						#docker stop sebackup > /dev/null 2>&1 && docker rm sebackup > /dev/null 2>&1

						# 生成无效信息
						#Apikey='none' && Email='none' && Password='none'
					    #Secret_id='none' && Secret_key='none' && Region='none' && Bucketname='none'
						#Tcuserid='none' && Tcpasswd='none' && Tcdevaddr='none'

						if [ ! -f /home/lnmpsite/backup/docker-compose-template.yml ]; then
							cp /home/lnmpsite/backup/docker-compose.yml /home/lnmpsite/backup/docker-compose-template.yml
						fi
						config=" \
ApiKey=${Apikey} \
UserEmail=${Email} \
UserPasswd=${Password} \
SecretID=${Secret_id} \
SecretKey=${Secret_key} \
Region=${Region} \
BucketName=${Bucketname} \
Tcuserid=${Tcuserid} \
Tcpasswd=${Tcpasswd} \
Tcdevaddr=${Tcdevaddr} "
						templ=`cat /home/lnmpsite/backup/docker-compose-template.yml`
						printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/lnmpsite/backup/docker-compose.yml
						touch /home/lnmpsite/backup/.passwd
					fi
				fi
			
				docker-compose up -d
				echo -e "${Info}站点备份机制已启用！"
			fi
		fi
	fi
	cd ${currpath}
}

function do_lnmpsite()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 LNMP 网站运行环境 ..."

	currpath=`pwd`
	if [ -d /home/lnmpsite ]; then
		stty erase '^H' && read -p "发现本地已存在 LNMP 网站运行环境，是否进行备份? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			${fsudo} mkdir -p /home/backsite
			${fsudo} tar zcvf /home/backsite/www`date +%Y%m%d.%H%M%S`.tar.gz /home/lnmpsite
			${fsudo} rm -rf /home/lnmpsite
		fi
	fi

	if [ -d /home/lnmpsite ]; then
		stty erase '^H' && read -p "在不备份的情况下是否删除原有 LNMP 网站运行环境并重新部署? [y/N]:" ynt && stty erase '^?' 
		[[ -z "${ynt}" ]] && ynt="n"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} rm -rf /home/lnmpsite
		fi
	fi

	if [ ! -d /home/lnmpsite ]; then
		cd /home
		${fsudo} git clone https://github.com/gorouter/lnmpsite.git
		${fsudo} mv /home/lnmpsite  /home/lnmpsite
		${fsudo} chmod +x /home/lnmpsite/lnmpsite
		[[ -f /usr/bin/lnmpsite ]] && ${fsudo} rm -f /usr/bin/lnmpsite
		${fsudo} ln -s /home/lnmpsite/lnmpsite /usr/bin/lnmpsite
	fi

	if [ -f /home/lnmpsite/docker-compose.yml ]; then

		if [ ! -f /home/lnmpsite/mysql/.passwd ]; then

			/home/lnmpsite/lnmpsite down > /dev/null 2>&1

			ftppwd=`cat /dev/urandom | head -n 12 | md5sum | head -c 12`
			echo -e "${Tip}请设置 FTP 用户(默认为 ${GreenFont}coder${FontEnd})密码"
			stty erase '^H' && read -p "(回车，默认密码为 ${ftppwd}):" ftppasswd && stty erase '^?' 
			[[ -z "${ftppasswd}" ]] && ftppasswd=${ftppwd}

			# 生成FTP安全数据
			ftpdsrv=`cat /home/lnmpsite/docker-compose.yml | grep lnmpsite-ftpd | awk -F 'image:' '{print $2}'`
			htmlmap='/home/lnmpsite/nginx/www:/home/ftpusers/coder'
			pureftp='/home/lnmpsite/ftpd/pure-ftpd:/etc/pure-ftpd'
			docker run -d --name seftpd -v ${htmlmap} -v ${pureftp} -e PUBLICHOST=localhost -e FTP_USER=coder -e FTP_PASSWORD=${ftppasswd} ${ftpdsrv}
			echo -e "${Tip}正在初始化FTP服务，请稍等 ... "
			sleep 5s
			docker exec seftpd bash -c "/usr/local/bin/ftpadd"
			sleep 1s
			docker stop seftpd > /dev/null 2>&1 && docker rm seftpd > /dev/null 2>&1
		
			# 开放端口信息
			iptables -D INPUT -p tcp -m multiport --dport 20,21 -m state --state NEW -j ACCEPT
			iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 21 -j ACCEPT
			iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 30000:30032 -j ACCEPT

			iptables -I INPUT -p tcp -m multiport --dport 20,21 -m state --state NEW -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 21 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 30000:30032 -j ACCEPT
			iptables-save > /etc/iptables.up.rules
			echo -e "${Tip}请牢记 FTP 用户 coder 的密码:${GreenFont} ${ftppasswd} ${FontEnd}"

			dbdefpwd=`cat /dev/urandom | head -n 12 | md5sum | head -c 12`
			echo -e "${Tip}请设置 MySQL 数据库 Root 密码"
			stty erase '^H' && read -p "(回车，默认密码为 ${dbdefpwd}):" dbpasswd && stty erase '^?' 
			[[ -z "${dbpasswd}" ]] && dbpasswd=${dbdefpwd}

			# 生成数据库安全数据
			mysqldb=`cat /home/lnmpsite/docker-compose.yml | grep lnmpsite-mysql | awk -F 'image:' '{print $2}'`
			datamap='/home/lnmpsite/mysql/data:/var/lib/mysql'
			confmap='/home/lnmpsite/mysql/my.cnf:/etc/my.cnf'
			docker run -d --name semysql -p 3306:3306 -v ${datamap} -v ${confmap} -e MYSQL_ROOT_PASSWORD=${dbpasswd} ${mysqldb}
			echo -e "${Tip}正在初始化数据库，请稍等 ... "
			sleep 10s
			docker exec semysql bash -c "/usr/local/bin/wpsinit"
			sleep 2s
			docker stop semysql > /dev/null 2>&1 && docker rm semysql > /dev/null 2>&1
			echo -e "${Tip}请牢记此数据库 ROOT 密码:${GreenFont} ${dbpasswd} ${FontEnd}"

			# 生成无效密码信息
			dbngpwd=`cat /dev/urandom | head -n 32 | md5sum | head -c 32`
			config=" \
FtpUser=coder \
FtpUserPasswd=${dbngpwd} \
MySQLpwd=${dbngpwd}"
			templ=`cat /home/lnmpsite/docker-compose.yml`
			printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/lnmpsite/docker-compose.yml
			touch /home/lnmpsite/mysql/.passwd
		fi

		# 查看日志信息 docker logs mysql
		cd /home/lnmpsite
		/home/lnmpsite/lnmpsite up
		echo -e "${Info}LNMP 网站运行环境部署完成."
	else
		echo -e "${Info}LNMP 网站运行环境部署失败，请检查！."
	fi
	cd ${currpath}
}

function do_javasite()
{
	checkdocker
	echo -e "${Info}正在部署基于DOCKER的 JWEB 网站运行环境 ..."

	currpath=`pwd`
	if [ -d /home/javasite ]; then
		stty erase '^H' && read -p "发现本地已存在 JWEB 网站运行环境，是否进行备份? [Y/n]:" yn && stty erase '^?' 
		[[ -z "${yn}" ]] && yn="y"
		if [[ $yn == [Yy] ]]; then
			${fsudo} mkdir -p /home/backsite
			${fsudo} tar zcvf /home/backsite/jweb`date +%Y%m%d.%H%M%S`.tar.gz /home/javasite
			${fsudo} rm -rf /home/javasite
		fi
	fi

	if [ -d /home/javasite ]; then
		stty erase '^H' && read -p "在不备份的情况下是否删除原有 JWEB 网站运行环境并重新部署? [y/N]:" ynt && stty erase '^?' 
		[[ -z "${ynt}" ]] && ynt="n"
		if [[ $ynt == [Yy] ]]; then
			${fsudo} rm -rf /home/javasite
		fi
	fi

	if [ ! -d /home/javasite ]; then
		cd /home
		${fsudo} git clone https://github.com/gorouter/javasite.git
		${fsudo} mv /home/javasite  /home/javasite
		${fsudo} chmod +x /home/javasite/japp
		[[ -f /usr/bin/japp ]] && ${fsudo} rm -f /usr/bin/japp
		${fsudo} ln -s /home/javasite/japp /usr/bin/japp
	fi

	if [ -f /home/javasite/docker-compose.yml ]; then

		if [ ! -f /home/javasite/mysql/.passwd ]; then

			/home/javasite/japp down > /dev/null 2>&1

			dbdefpwd=`cat /dev/urandom | head -n 12 | md5sum | head -c 12`
			echo -e "${Tip}请设置 MySQL 数据库 Root 密码"
			stty erase '^H' && read -p "(回车，默认密码为 ${dbdefpwd}):" dbpasswd && stty erase '^?' 
			[[ -z "${dbpasswd}" ]] && dbpasswd=${dbdefpwd}

			# 生成数据库安全数据
			mysqldb=`cat /home/javasite/docker-compose.yml | grep lnmpsite-mysql | awk -F 'image:' '{print $2}'`
			datamap='/home/javasite/mysql/data:/var/lib/mysql'
			confmap='/home/javasite/mysql/my.cnf:/etc/my.cnf'
			docker run -d --name semysql -p 3306:3306 -v ${datamap} -v ${confmap} -e MYSQL_ROOT_PASSWORD=${dbpasswd} ${mysqldb}
			echo -e "${Tip}正在初始化数据库，请稍等 ... "
			sleep 10s
			docker exec semysql bash -c "/usr/local/bin/wpsinit"
			sleep 2s
			docker stop semysql > /dev/null 2>&1 && docker rm semysql > /dev/null 2>&1
			echo -e "${Tip}请牢记此数据库 ROOT 密码:${GreenFont} ${dbpasswd} ${FontEnd}"

			# 生成无效密码信息
			dbngpwd=`cat /dev/urandom | head -n 32 | md5sum | head -c 32`
			config=" \
MySQLpwd=${dbngpwd}"
			templ=`cat /home/javasite/docker-compose.yml`
			printf "${config}\ncat << EOF\n${templ}\nEOF" | bash > /home/javasite/docker-compose.yml
			touch /home/javasite/mysql/.passwd
		fi

		# 查看日志信息 docker logs mysql
		cd /home/javasite
		/home/javasite/japp up
		echo -e "${Info}JWEB 网站运行环境部署完成."
	else
		echo -e "${Info}JWEB 网站运行环境部署失败，请检查！."
	fi
	cd ${currpath}
}

function do_update()
{
	[[ -f /usr/bin/vps ]] && rm -f /usr/bin/vps 
	wget -N --no-check-certificate -q -O /usr/bin/vps https://raw.githubusercontent.com/programs/scripts/master/vps/setup.sh && chmod +x /usr/bin/vps 
	clear && vps
	echo -e "${Info}更新程序到最新版本 完成!"
}

function do_inspeeder()
{
	wget -N --no-check-certificate -q -O /home/bin/speeder.sh ${url_speederall} && chmod +x /home/bin/speeder.sh
	echo -e "${Tip}当前四合一提速脚本已下载, 如需要请自行选择提速方案"
	echo -e "${Tip}可以执行此命令: ${GreenFont}/home/bin/speeder.sh${FontEnd}"

	stty erase '^H' && read -p "是否确定只布署适合 ubuntu16.04 的锐速? (暂不提供卸载操作) [Y/n] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then

		wget -N --no-check-certificate -q -O /home/bin/ruisu.sh ${url_speeder} && chmod +x /home/bin/ruisu.sh
		/home/bin/ruisu.sh 
	fi
}

function do_uninsfrp()
{
	if [ -f /etc/supervisor/conf.d/frp.conf ]; then
		echo -e "${Info}正在移除 FRP 环境..."

		# 关闭端口
		iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 7137 -j ACCEPT
		iptables -D INPUT -p udp -m state --state NEW -m udp --dport 7137:7138 -j ACCEPT
		iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 8000:9000 -j ACCEPT
		iptables-save > /etc/iptables.up.rules

		systemctl stop supervisor
		apt-get remove -y supervisor
		[[ -f /etc/supervisor/conf.d/frp.conf ]] && rm -f /etc/supervisor/conf.d/frp.conf
		[[ -d /home/frp ]] && rm -rf /home/frp
		rm -f /home/frps*.log
	fi

	echo -e "${Info}完成 FRP 环境的移除."
}

function do_uninsssr()
{
	if [ ! -f /home/bin/ssrmu.sh ]; then
		wget -N --no-check-certificate -q -O /home/bin/ssrmu.sh ${url_ssrmu}
		chmod +x /home/bin/ssrmu.sh
	fi
	/home/bin/ssrmu.sh

	ssr_folder='/usr/local/shadowsocksr'
	if [ ! -e ${ssr_folder} ]; then 
		do_uninsfrp

		echo -e "${Info}SSR 及其 FRP 环境已全部移除！"
	fi
}

function do_uninssh()
{
	stty erase '^H' && read -p "是否确定重置 ssh 授权密钥环境? [Y/n] :" yn && stty erase '^?' 
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then

		echo -e "${Tip}正在重置 SSH 授权密钥环境..."
		if [ -f /home/${defaultuser}/.ssh/authorized_keys ]; then
			
			chattr -i /home/${defaultuser}/.ssh/authorized_keys
			chattr -i /home/${defaultuser}/.ssh
			chmod 755 /home/${defaultuser}/.ssh/authorized_keys

			rm -rf /home/${defaultuser}/.ssh
		fi

		echo -e "${Tip}正在重置 SSH 防火墙端口为 ${GreenFont}19022${FontEnd}"
		iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 19022 -j ACCEPT
		iptables -D INPUT -p tcp -m state --state NEW -m tcp --dport 18022 -j ACCEPT
		iptables -D INPUT -p udp -m state --state NEW -m udp --dport 18022 -j ACCEPT
		iptables-save > /etc/iptables.up.rules
		iptables-restore < /etc/iptables.up.rules

		sed -i "/^PasswordAuthentication/c\PasswordAuthentication yes" /etc/ssh/sshd_config
		sed -i "/^PermitRootLogin/c\PermitRootLogin yes" /etc/ssh/sshd_config
		sed -i "/^Port/c\Port 19022" /etc/ssh/sshd_config
		service sshd restart
	fi
}

function do_uninstall()
{
	do_removenq
	do_uninsssr
	do_uninsdocker
	do_uninssh
	do_deluser

    echo -e "${Info}请重置当前 VPS 的 root 密码!"
	passwd
	echo -e "${Info}当前 VPS 环境已重置."
}

function do_version() {
	echo -e "${GreenFont}${0##*/}${FontEnd} V 1.0.0 "
}

#主程序入口
echo -e "${GreenFont}
+-----------------------------------------------------
| VPS Script 1.x FOR Ubuntu/Debian
+-----------------------------------------------------
| Copyright © 2015-2019 programs All rights reserved.
+-----------------------------------------------------
${FontEnd}"

checkSystem
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
action=$1
[[ -z $1 ]] && action=help
case "$action" in
	version | install | uninstall | mtproxy | javasite | inspeeder | setupfrp | uninsfrp | wpdisable | wpenable | wordpress | wpnewsite | wpupdate | wpbackup | wprestore | setupvray | setupssr | uninsssr | vrayworld | ssrworld | ssrmdport | ssripv6 | redoswap | update | speedtest | lnmpsite | bbrstatus | ssrstatus | sysupgrade | adduser | deluser | ssrmu | uninsdocker | iptable | configssh | qsecurity | editfrp | frpsecurity | enableipv6 | makedocker | nodequery | removenq)
	checkRoot
	do_${action}
	;;
	ensshkeys)
	do_ensshkeys
	;;
	bansshkey)
	do_bansshkey
	;;
	*)
	echo " "
	echo -e "用法: ${GreenFont}${0##*/}${FontEnd} [指令]"
	echo "指令:"
	echo "    update     -- 更新程序到最新版本"
	echo "    version    -- 显示版本信息"
	echo ""
	echo -e " -- ${GreenFont}初始化${FontEnd} --"
	echo "    install    -- 安装并初始化 VPS 环境"
	echo "    uninstall  -- 重置 VPS 环境"
	echo "    bbrstatus  -- 查看 BBR 状态"
	echo "    speedtest  -- 测试网络速度"
	echo "    qsecurity  -- 查询本地安全信息"
	echo ""
	echo "    ensshkeys  -- 配置 SSH 登陆使用授权密钥   (须非ROOT用户环境)"
	echo "    bansshkey  -- 允许 SSH 登陆不使用授权密钥 (须非ROOT用户环境)"
	echo ""
	echo -e " -- ${GreenFont}系统${FontEnd} --"
	echo "    redoswap   -- 创建或重建交换分区"
	echo "    sysupgrade -- 系统更新"
	echo "    adduser    -- 新增用户"
	echo "    deluser    -- 删除用户"
	echo "    iptable    -- 修改 防火墙"
	echo "    configssh  -- 修改 SSH 配置"
	echo "    enableipv6 -- 开关系统 IPv6"
	echo ""
	echo -e " -- ${GreenFont}虚拟化${FontEnd} --"
	echo "    makedocker -- 生成 DOCKER 运行环境"
	echo "    uninsdocker-- 移除 DOCKER 运行环境"
	echo "    lnmpsite   -- 部署 LNMP 环境 (DOCKER环境)"
	echo "    javasite   -- 部署 JWEB 环境 (DOCKER环境)"
	echo "    ssrworld   -- 部署 SSR  环境 (DOCKER环境)"
	echo "    vrayworld  -- 部署 V2Ray环境 (DOCKER环境)"
	echo "    mtproxy    -- 部署 Telegram 代理 (DOCKER环境)"
	echo ""
	echo -e " -- ${GreenFont}博士站${FontEnd} --"
	echo "    wordpress  -- 部署 BLOG 站点"
	echo "    wpupdate   -- 升级 BLOG 站点(仅主站)"
	echo "    wpbackup   -- 备份 BLOG 站点"
	echo "    wprestore  -- 恢复 BLOG 站点"
	echo "    wpnewsite  -- 新建 BLOG 站点(仅子站)"
	echo ""
	echo "    wpenable   -- 开启全站可读写权限"
	echo "    wpdisable  -- 禁用全站可读写权限"
	echo ""
	echo -e " -- ${GreenFont}看世界${FontEnd} --"
	echo "    setupssr   -- 安装并初始化 SSR 环境"
	echo "    uninsssr   -- 移除 SSR 及其 FRP 环境"
	echo "    ssrmu      -- 运行 SSR 修改或增加配置"
	echo "    ssripv6    -- 开关 SSR 的 IPv6"
	echo "    ssrmdport  -- 重新设置 SSR 端口(仅单用户)"
	echo "    ssrstatus  -- 查看 SSR 状态"
	echo ""
	echo "    setupfrp   -- 安装单独的 FRP 环境"
	echo "    uninsfrp   -- 移除单独的 FRP 环境"
	echo "    editfrp    -- 修改 FRP 配置"
	echo "    frpsecurity-- 修改 FRP 面板密码及令牌"
	echo "" 
	echo "    inspeeder  -- 安装 bbr (原版/魔改/plus) + 锐速"
	echo "    setupvray  -- 安装并初始化 V2Ray环境"
	echo ""
	echo -e " -- ${GreenFont}监控${FontEnd} --"
	echo "    nodequery  -- 增加 nodequery 监控"
	echo "    removenq   -- 移除 nodequery 监控"
	echo " "
	;;
esac
