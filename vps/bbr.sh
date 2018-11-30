#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/home/bin:~/bin
export PATH

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

function setLastNewKernel()
{
	echo -e "请输入 要下载安装的Linux内核版本(BBR) [ 格式: x.xx.xx ，例如: 4.9.135 ]
${Tip} 内核版本列表请去这里获取：[ http://kernel.ubuntu.com/~kernel-ppa/mainline/ ]
如果只在乎稳定，那么不需要追求最新版本（新版本不会保证稳定性），可以选择 4.9.XX 稳定版本。"
	stty erase '^H' && read -p "(默认回车，自动获取最新版本):" latest_version
	[[ -z "${latest_version}" ]] && getLastestKernel
	echo
}

function getLastestKernel()
{
	echo -e "${Info} 检测内核最新版本中..."
	latest_version=$(wget -qO- "http://kernel.ubuntu.com/~kernel-ppa/mainline/" | awk -F'\"v' '/v[4-9].[0-9]*.[0-9]/{print $2}' |grep -v '\-rc'| cut -d/ -f1 | sort -V | tail -1)
	[[ -z ${latest_version} ]] && echo -e "${Error} 检测内核最新版本失败 !" && exit 1
	echo -e "${Info} 当前内核最新版本为 : ${latest_version}"
}

function getLatestVersion()
{
	setLastNewKernel
	bit=`uname -m`
	if [[ ${bit} == "x86_64" ]]; then
		deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
		deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
		deb_kernel_name="linux-image-${latest_version}-amd64.deb"

		deb_module=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "modules" | grep "generic" | awk -F'\">' '/amd64.deb/{print $2}' | cut -d'<' -f1 | head -1)
		if [ ! -z "${deb_module}" ]; then
		    deb_module_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_module}"
		    deb_module_name="linux-module-${latest_version}-amd64.deb"
		fi
	else
		deb_name=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "linux-image" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
		deb_kernel_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_name}"
		deb_kernel_name="linux-image-${latest_version}-i386.deb"

		deb_module=$(wget -qO- http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/ | grep "modules" | grep "generic" | awk -F'\">' '/i386.deb/{print $2}' | cut -d'<' -f1 | head -1)
		if [ ! -z "${deb_module}" ]; then
		    deb_module_url="http://kernel.ubuntu.com/~kernel-ppa/mainline/v${latest_version}/${deb_module}"
		    deb_module_name="linux-module-${latest_version}-i386.deb"
		fi
	fi
}

#检查内核是否满足
function checkKernelStatus()
{
	getLastestKernel
	deb_ver=`dpkg -l|grep linux-image | awk '{print $3}' | awk -F '-' '{print $1}' | grep '[4-9].[0-9]*.'`
	latest_version_2=$(echo "${latest_version}"|grep -o '\.'|wc -l)
	if [[ "${latest_version_2}" == "1" ]]; then
		latest_version="${latest_version}.0"
	fi
	if [[ "${deb_ver}" != "" ]]; then
		if [[ "${deb_ver}" == "${latest_version}" ]]; then
			echo -e "${Info} 检测到 当前内核版本[${deb_ver}] 已满足要求，继续..."
		else
			echo -e "${Tip} 检测到 当前内核版本[${deb_ver}] 支持开启BBR但不是最新内核版本，可以使用${GreenFont} bash ${file}/bbr.sh ${FontEnd}来升级内核 !(注意：并不是越新的内核越好，4.9 以上版本的内核 目前皆为测试版，不保证稳定性，旧版本如使用无问题 建议不要升级！)"
		fi
	else
		echo -e "${Error} 检测到 当前内核版本[${deb_ver}] 不支持开启BBR，请使用${GreenFont} bash ${file}/bbr.sh ${FontEnd}来更换最新内核 !" && exit 1
	fi
}

#删除其余内核
function deleteOtherKernel()
{
	deb_total=`dpkg -l | grep linux-image | awk '{print $2}' | grep -v "${latest_version}" | wc -l`
	if [[ "${deb_total}" -ge "1" ]]; then
		echo -e "${Info} 检测到 ${deb_total} 个其余内核，开始卸载..."
		for((integer = 1; integer <= ${deb_total}; integer++))
		do
			deb_del=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${latest_version}" | head -${integer}`
			#deb_del_module=`dpkg -l|grep linux-modules | awk '{print $2}' | grep -v "${latest_version}" | head -${integer}`

			echo -e "${Info} 开始卸载 ${deb_del} 内核..."
			#[ ! -z "${deb_del_module}" ] && apt-get purge -y ${deb_del_module}
			apt-get purge -y ${deb_del}
			echo -e "${Info} 卸载 ${deb_del} 内核卸载完成，继续..."
		done
		deb_total=`dpkg -l|grep linux-image | awk '{print $2}' | wc -l`
		if [[ "${deb_total}" = "1" ]]; then
			echo -e "${Info} 内核卸载完毕，继续..."
		else
			echo -e "${Error} 内核卸载异常，请检查 !" && exit 1
		fi
	else
		echo -e "${Info} 检测到 除刚安装的内核以外已无多余内核，跳过卸载多余内核步骤 !"
	fi
}

function bbrCleanup()
{
	deleteOtherKernel
	update-grub
	addsysctl
	(echo 'y') | apt autoremove
	echo -e "${Tip} 重启VPS后，请重新运行脚本查看BBR是否加载成功，运行命令： ${GreenBack} bash ${file}/bbr.sh status ${FontEnd}"
	stty erase '^H' && read -p "需要重启VPS后，才能开启BBR，是否现在重启 ? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} VPS 重启中..."
		reboot
	fi
}

#安装BBR
function bbrinstall()
{
	checkRoot
	getLatestVersion
	deb_ver=`dpkg -l|grep linux-image | awk '{print $3}' | awk -F '-' '{print $1}' | grep '[4-9].[0-9]*.'`
	latest_version_2=$(echo "${latest_version}"|grep -o '\.'|wc -l)
	if [[ "${latest_version_2}" == "1" ]]; then
		latest_version="${latest_version}.0"
	fi
	if [[ "${deb_ver}" != "" ]]; then	
		if [[ "${deb_ver}" == "${latest_version}" ]]; then
			echo -e "${Info} 检测到 当前内核版本 已是最新版本，无需继续 !"
			deb_total=`dpkg -l|grep linux-image | awk '{print $2}' | grep -v "${latest_version}" | wc -l`
			if [[ "${deb_total}" != "0" ]]; then
				echo -e "${Info} 检测到内核数量异常，存在多余内核，开始删除..."
				bbrCleanup
			else
				exit 1
			fi
		else
			echo -e "${Info} 检测到 当前内核版本支持开启BBR 但不是最新内核版本，升级(或降级)内核..."
		fi
	else
		echo -e "${Info} 检测到 当前内核版本 不支持开启BBR，开始..."
		virt=`virt-what`
		if [[ -z ${virt} ]]; then
			apt-get update && apt-get install -y --no-install-recommends virt-what
			virt=`virt-what`
		fi
		if [[ ${virt} == "openvz" ]]; then
			echo -e "${Error} BBR 不支持 OpenVZ 虚拟化 !" && exit 1
		fi
	fi
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	echo "nameserver 8.8.4.4" >> /etc/resolv.conf
	
	wget -O "${deb_kernel_name}" "${deb_kernel_url}"
	if [[ -s ${deb_kernel_name} ]]; then
		echo -e "${Info} 内核文件下载成功，开始安装内核..."

        if [ ! -z "${deb_module}" ]; then
			#某此内核需要modules的支持
			wget -O "${deb_module_name}" "${deb_module_url}"
			if [[ -s ${deb_module_name} ]]; then
				dpkg -i ${deb_module_name}
				rm -rf ${deb_module_name}
			fi
		fi

		dpkg -i ${deb_kernel_name}
		rm -rf ${deb_kernel_name}
	else
		echo -e "${Error} 内核文件下载失败，请检查 !" && exit 1
	fi

	#判断内核是否安装成功
	deb_ver=`dpkg -l | grep linux-image | awk '{print $3}' | awk -F '-' '{print $1}' | grep "${latest_version}"`
	if [[ "${deb_ver}" != "" ]]; then
		echo -e "${Info} 检测到 内核 已安装成功，开始卸载其余内核..."
		bbrCleanup
	else
		echo -e "${Error} 检测到 内核版本 安装失败，请检查 !" && exit 1
	fi
}

function checkBbrStatus()
{
	check_bbr_status_on=`sysctl net.ipv4.tcp_congestion_control | awk '{print $3}'`
	if [[ "${check_bbr_status_on}" = "bbr" ]]; then
		echo -e "${Info} 检测到 BBR 已开启 !"
		# 检查是否启动BBR
		check_bbr_status_off=`lsmod | grep bbr`
		if [[ "${check_bbr_status_off}" = "" ]]; then
			echo -e "${Error} 检测到 BBR 已开启但未正常启动，请检查(可能是存着兼容性问题，虽然内核配置中打开了BBR，但是内核加载BBR模块失败) !"
		else
			echo -e "${Info} 检测到 BBR 已开启并已正常启动 !"
		fi
		exit 1
	fi
}

function addsysctl()
{
	sed -i '/net\.core\.default_qdisc=fq/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control=bbr/d' /etc/sysctl.conf
	
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
	sysctl -p
}

#启动BBR
function bbrstart()
{
	checkKernelStatus
	checkBbrStatus
	addsysctl
	sleep 1s
	checkBbrStatus
}

#关闭BBR
function bbrstop()
{
	checkKernelStatus
	sed -i '/net\.core\.default_qdisc=fq/d' /etc/sysctl.conf
	sed -i '/net\.ipv4\.tcp_congestion_control=bbr/d' /etc/sysctl.conf
	sysctl -p
	sleep 1s
	
	stty erase '^H' && read -p "需要重启VPS后，才能彻底停止BBR，是否现在重启 ? [Y/n] :" yn
	[[ -z "${yn}" ]] && yn="y"
	if [[ $yn == [Yy] ]]; then
		echo -e "${Info} VPS 重启中..."
		reboot
	fi
}

#查看BBR状态
function bbrstatus()
{
	checkKernelStatus
	checkBbrStatus
	echo -e "${Error} BBR 未开启 !"
}

#主程序入口
checkSystem
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
action=$1
[[ -z $1 ]] && action=install
case "$action" in
	install|start|stop|status)
	bbr${action}
	;;
	*)
	echo "输入错误 !"
	echo "用法: { install | start | stop | status }"
	;;
esac
