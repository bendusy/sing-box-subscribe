#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 获取服务器IP
get_ip() {
    # 尝试多种方式获取公网IP
    IP=$(curl -s http://ipv4.icanhazip.com || \
         curl -s http://api.ipify.org || \
         curl -s http://ifconfig.me)
    
    if [ -z "$IP" ]; then
        # 如果无法获取公网IP，尝试获取内网IP
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$IP" ]; then
        echo "无法获取服务器IP"
        IP="YOUR_IP"
    fi
    
    echo $IP
}

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
        # 检查并安装Python
        if ! command -v python3 &> /dev/null; then
            echo "正在安装 Python3..."
            apt-get update
            apt-get install -y python3 python3-pip python-is-python3
        fi
        
        # 安装依赖
        echo "安装Python依赖..."
        python3 -m pip install --upgrade pip
        python3 -m pip install -r requirements.txt
        
        # 检查Flask是否正确安装
        if ! python3 -c "import flask" &> /dev/null; then
            echo -e "${RED}Flask安装失败，尝试重新安装...${NC}"
            python3 -m pip install flask --upgrade
        fi
        
        # 启动服务
        echo -e "${GREEN}启动服务...${NC}"
        # 使用nohup后台运行
        nohup python3 main.py > sing-box.log 2>&1 &
        
        # 等待服务启动
        sleep 3
        if pgrep -f "python3 main.py" > /dev/null; then
            echo -e "${GREEN}Python服务已成功启动${NC}"
        else
            echo -e "${RED}Python服务启动失败，请检查sing-box.log文件${NC}"
            tail -n 10 sing-box.log
            exit 1
        fi
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
        docker run -d --name sing-box -p 5000:5000 sing-box:latest
        
        # 检查容器是否正常运行
        if [ "$(docker ps -q -f name=sing-box)" ]; then
            echo -e "${GREEN}Docker容器已成功启动${NC}"
        else
            echo -e "${RED}Docker容器启动失败${NC}"
            docker logs sing-box
            exit 1
        fi
        ;;
        
    *)
        echo "无效的选择，请使用 1/python 或 2/docker 作为参数"
        exit 1
        ;;
esac

# 获取服务器IP
SERVER_IP=$(get_ip)

echo -e "${GREEN}部署完成!${NC}"
echo "如果选择Python部署,服务已在后台运行"
echo "如果选择Docker部署,服务已在后台运行"
echo -e "${BLUE}可以通过 http://${SERVER_IP}:5000 访问服务${NC}"
echo "查看日志: tail -f sing-box.log" 