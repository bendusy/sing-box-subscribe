#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查是否已存在目录
if [ -d "sing-box-subscribe" ]; then
    echo "检测到已存在sing-box-subscribe目录，正在删除..."
    rm -rf sing-box-subscribe
fi

echo -e "${BLUE}开始部署 sing-box-subscribe...${NC}"

# 检查git是否安装
if ! command -v git &> /dev/null; then
    echo "正在安装 git..."
    apt-get update && apt-get install -y git
fi

# 克隆仓库
echo "克隆项目仓库..."
git clone https://github.com/bendusy/sing-box-subscribe.git
cd sing-box-subscribe

# 获取部署方式
# 如果没有参数，则进行交互式选择
if [ -z "$1" ]; then
    echo -e "${GREEN}请选择部署方式:${NC}"
    echo "1) Python直接部署"
    echo "2) Docker部署"
    read -p "请输入选择(1-2): " choice
else
    choice=$1
fi

case $choice in
    1|"python")
        echo -e "${BLUE}开始Python部署...${NC}"
        # 检查Python是否安装
        if ! command -v python3 &> /dev/null; then
            echo "正在安装 Python3..."
            apt-get update && apt-get install -y python3 python3-pip
        fi
        
        # 安装依赖
        echo "安装Python依赖..."
        pip3 install -r requirements.txt
        
        # 启动服务
        echo -e "${GREEN}启动服务...${NC}"
        python3 main.py
        ;;
        
    2|"docker")
        echo -e "${BLUE}开始Docker部署...${NC}"
        # 检查Docker是否安装
        if ! command -v docker &> /dev/null; then
            echo "正在安装 Docker..."
            curl -fsSL https://get.docker.com | sh
        fi
        
        # 构建镜像
        echo "构建Docker镜像..."
        docker build --tag 'sing-box' .
        
        # 运行容器
        echo -e "${GREEN}启动Docker容器...${NC}"
        docker run -d -p 5000:5000 sing-box:latest
        ;;
        
    *)
        echo "无效的选择，请使用 1/python 或 2/docker 作为参数"
        exit 1
        ;;
esac

echo -e "${GREEN}部署完成!${NC}"
echo "如果选择Python部署,服务已在终端运行"
echo "如果选择Docker部署,服务已在后台运行,端口5000"
echo -e "${BLUE}可以通过 http://YOUR_IP:5000 访问服务${NC}" 