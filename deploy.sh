#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# 清理函数
cleanup() {
    echo "开始清理环境..."
    
    # 停止并清理Python服务
    pkill -f "python main.py"
    rm -rf venv
    rm -f sing-box.log
    rm -f start.sh
    
    # 停止并清理Docker服务
    if command -v docker &> /dev/null; then
        if [ "$(docker ps -q -f name=sing-box)" ]; then
            docker stop sing-box
            docker rm sing-box
        fi
        if [ "$(docker images -q sing-box)" ]; then
            docker rmi sing-box
        fi
    fi
    
    # 删除项目目录
    cd ..
    if [ -d "sing-box-subscribe" ]; then
        rm -rf sing-box-subscribe
    fi
    
    echo "清理完成"
}

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

# 执行清理
cleanup

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
        # 检查并安装Python相关包
        echo "安装Python相关包..."
        apt-get update
        apt-get install -y python3 python3-pip python3-venv python3-full python-is-python3

        # 创建并激活虚拟环境
        echo "创建虚拟环境..."
        python3 -m venv venv
        source venv/bin/activate

        # 安装依赖
        echo "安装Python依赖..."
        pip install --upgrade pip wheel setuptools
        pip install -r requirements.txt
        pip install flask scp requests pyyaml ruamel.yaml paramiko

        # 检查依赖是否正确安装
        echo "检查依赖安装..."
        for package in flask scp requests pyyaml "ruamel.yaml"; do
            if ! python -c "import ${package//.//}" &> /dev/null; then
                echo -e "${RED}${package} 安装失败${NC}"
                exit 1
            fi
        done
        
        # 创建启动脚本
        echo "创建启动脚本..."
        cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
nohup python main.py > sing-box.log 2>&1 &
EOF
        chmod +x start.sh
        
        # 启动服务
        echo -e "${GREEN}启动服务...${NC}"
        ./start.sh
        
        # 等待服务启动
        sleep 3
        if pgrep -f "python main.py" > /dev/null; then
            echo -e "${GREEN}Python服务已成功启动${NC}"
            # 显示最近的日志
            echo -e "\n最近的日志输出:"
            tail -n 10 sing-box.log
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
            # 显示容器日志
            echo -e "\n容器日志输出:"
            docker logs sing-box
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

# 添加服务管理说明
echo -e "\n${GREEN}服务管理说明:${NC}"
if [ "$choice" = "1" ] || [ "$choice" = "python" ]; then
    echo "启动服务: ./start.sh"
    echo "停止服务: pkill -f 'python main.py'"
    echo "查看日志: tail -f sing-box.log"
    echo "重新部署: bash deploy.sh python"
else
    echo "启动服务: docker start sing-box"
    echo "停止服务: docker stop sing-box"
    echo "查看日志: docker logs -f sing-box"
    echo "重新部署: bash deploy.sh docker"
fi 