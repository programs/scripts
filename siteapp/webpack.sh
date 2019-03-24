#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/home/bin:~/bin
export PATH

LANG=en_US.UTF-8

# 用法
# wget -N --no-check-certificate -q -O ./webp https://raw.githubusercontent.com/programs/scripts/master/siteapp/webpack.sh && chmod +x ./webp && webp
#
GreenFont="\033[32m" && RedFont="\033[31m" && GreenBack="\033[42;37m" && RedBack="\033[41;37m" && FontEnd="\033[0m"
Info="${GreenFont}[信息]${FontEnd}"
Error="${RedFont}[错误]${FontEnd}"
Tip="${GreenFont}[注意]${FontEnd}"
filepath=$(cd "$(dirname "$0")"; pwd)
file=$(echo -e "${filepath}"|awk -F "$0" '{print $1}')

function do_default()
{
    mkdir -p ${filepath}/build  \
             ${filepath}/config \
             ${filepath}/dist   \
             ${filepath}/doc    \
             ${filepath}/src

    mkdir -p ${filepath}/src/common  \
             ${filepath}/src/backend \
             ${filepath}/src/libs    \
             ${filepath}/src/html    \
             ${filepath}/src/assets

    mkdir -p ${filepath}/src/assets/css  \
             ${filepath}/src/assets/img  \
             ${filepath}/src/assets/sass \
             ${filepath}/src/assets/less

    echo "done."
}

function p_createWebpackConfig()
{
    echo "
var path = require('webpack');
module.exports = {
    entry: [__dirname+'/src/index.js'],  // 项目入口文件的路径,可以有多个文件
    output: { // 定义webpack输出
        path: __dirname+'/dist',
        publicPath:__dirname+'/dist/',
        filename: 'index_bundle.js'
    },
    module: {
        loaders: [
            {   // json加载器 
                test: /\.json$/,
                loader: 'json-loader'
            },
            {   // 编译ES6语法配置
                test: /\.js$/,          // 匹配文件的正则
                loader: 'babel-loader', // 指定调用loader去处理对应文件类型
                exclude: /node_modules/,
                query: {
                    presets: ['es2015', 'react']
                }
            },
            {   // CSS加载器
                test: /\.css$/,
                loader: 'style-loader!css-loader'
            },
            {   // 解析.vue文件
                test:/\.vue$/,
                loader:'vue-loader'
            },
            {   // 图片转化,小于8K自动转化为base64的编码
                test: /\.(png|jpg|gif)$/,
                loader:'url-loader?limit=8192'
            }
        ]
    },
    vue:{
        loaders:{
            js:'babel-loader'
        }
    },
    resolve: {
        // require时省略的扩展名, 如：require('app') 不需要app.js
        extensions: ['', '.js', '.vue'],
        // 配置简写，路径可以省略文件类型
        alias: {
            filter: path.join(__dirname, './src/filters'),
            components: path.join(__dirname, './src/components')
        }
    }, 
    devServer: { // 服务器依赖包配置, 注意: 网上很多都有colors属性, 但是实际上的webpack2.x已经不支持该属性了
        contentBase: __dirname+''/src/html', // 本地服务器所加载的页面所在的目录
        historyApiFallback: true, // 不跳转
        inline: true // 实时刷新
        hot: false,  // 让浏览器自动更新
        publicPath: '/asses/'', // 设置该属性后, webpack-dev-server会相对于该路径
        grogress: true
    },
    plugins:[] // 插件
}
    " >> ./webpack.config.js
}

function do_init()
{
    #npm install -g cnpm --registry=https://registry.npm.taobao.org
    npm init
    npm install --save-dev webpack 

    npm install --save-dev css-loader style-loader json-loader url-loader file-loader
    npm install --save-dev wechat-mina-loader node-sass postcss-loader less less-loader
    npm install --save-dev vue vue-cli vue-router vue-loader vue-style-loader vue-template-compiler 
    npm install --save-dev react react-dom react-router
    npm install --save-dev pug ramda regenerator-runtime lodash shelljs express

    npm install --save-dev webpack-dev-server copy-webpack-plugin progress-bar-webpack-plugin extract-text-webpack-plugin html-webpack-plugin
    npm install --save-dev babel-core babel-loader babel-plugin-import babel-preset-2015 babel-preset-react babel-preset-env

    touch webpack.config.js
    p_createWebpackConfig()
    echo "done."
}

function do_update()
{
	[[ -f ./webp ]] && rm -f ./webp 
	wget -N --no-check-certificate -q -O ./webp https://raw.githubusercontent.com/programs/scripts/master/siteapp/webpack.sh && chmod +x ./webp 
	clear && ./webp
	echo -e "${Info}更新程序到最新版本 完成!"
}

function do_version() {
	echo -e "${GreenFont}${0##*/}${FontEnd} V 1.0.0 "
}

#主程序入口
echo -e "${GreenFont}
+-----------------------------------------------------
| Webpack Script 1.x 
+-----------------------------------------------------
| Copyright © 2015-2019 programs All rights reserved.
+-----------------------------------------------------
${FontEnd}"

action=$1
[[ -z $1 ]] && action=help
case "$action" in
	version | update | init | default)
    do_${action}
	;;
	*)
	echo " "
	echo -e "用法: ${GreenFont}${0##*/}${FontEnd} [指令]"
	echo "指令:"
	echo "    update     -- 更新程序到最新版本"
	echo "    version    -- 显示版本信息"
	echo ""
	echo -e " -- ${GreenFont}初始化${FontEnd} --"
    echo "    default    -- 创建默认项目目录结构"
	echo "    init       -- 初始化 webpack 环境"
	echo " "
	;;
esac
