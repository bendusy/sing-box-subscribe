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
    IP=$(curl -s http://ipv4.icanhazip.com || \
         curl -s http://api.ipify.org || \
         curl -s http://ifconfig.me)
    
    if [ -z "$IP" ]; then
        IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$IP" ]; then
        echo "无法获取服务器IP"
        IP="YOUR_IP"
    fi
    
    echo $IP
}

# 选择配置模板
select_template() {
    # 如果是非交互式环境，使用默认模板
    if [ ! -t 0 ]; then
        echo -e "${BLUE}非交互式环境，使用默认模板 (4) config_template_test${NC}"
        return 3
    fi

    while true; do
        echo -e "\n${BLUE}可用的配置模板:${NC}"
        echo "1) config_template_groups_rule_set_tun"
        echo "2) config_template_groups_rule_set_tun_fakeip"
        echo "3) config_template_no_groups_tun_VN"
        echo "4) config_template_test"
        echo "5) config_template_test_dns"
        echo "6) sb-config-1.11"
        
        read -p "请选择配置模板 (1-6) [默认4]: " template_choice
        case $template_choice in
            1) return 0 ;;
            2) return 1 ;;
            3) return 2 ;;
            4|"") return 3 ;;
            5) return 4 ;;
            6) return 5 ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                continue
                ;;
        esac
    done
}

# 获取订阅地址
get_subscription_url() {
    # 如果是非交互式环境，提示用户需要提供订阅地址
    if [ ! -t 0 ]; then
        echo "请使用 --sub 参数提供订阅地址"
        exit 1
    fi

    while true; do
        read -p "请输入您的订阅地址: " sub_url
        if [ -n "$sub_url" ]; then
            if curl -s "$sub_url" &> /dev/null; then
                echo "$sub_url"
                return 0
            else
                echo -e "${RED}无法访问订阅地址，请检查后重新输入${NC}"
            fi
        else
            echo -e "${RED}订阅地址不能为空${NC}"
        fi
    done
}

# 生成分享URL
generate_share_url() {
    local server_ip="$1"
    local sub_url="$2"
    local template_index="$3"
    encoded_url=$(python -c "import urllib.parse; print(urllib.parse.quote('''$sub_url'''))")
    echo "http://${server_ip}:5000/config/${encoded_url}?file=${template_index}"
}

# 部署Python环境
deploy_python() {
    echo -e "${BLUE}开始Python环境部署...${NC}"
    
    # 安装Python相关包
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

    # 修改Flask监听地址
    echo "配置Flask监听地址..."
    if [ -f main.py ]; then
        sed -i 's/app.run()/app.run(host="0.0.0.0", port=5000)/' main.py
    fi
}

# 部署Docker环境
deploy_docker() {
    echo -e "${BLUE}开始Docker环境部署...${NC}"
    
    # 安装Docker
    if ! command -v docker &> /dev/null; then
        echo "正在安装 Docker..."
        curl -fsSL https://get.docker.com | sh
    fi

    # 构建镜像
    echo "构建Docker镜像..."
    docker build --tag 'sing-box' .
}

# 启动服务
start_service() {
    local deploy_type="$1"
    local template_index="$2"
    local subscription_url="$3"
    
    echo -e "${GREEN}启动服务...${NC}"
    if [ "$deploy_type" = "python" ]; then
        # 创建启动脚本
        cat > start.sh << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
source venv/bin/activate
nohup python main.py --template_index=$template_index "$subscription_url" > sing-box.log 2>&1 &
EOF
        chmod +x start.sh
        ./start.sh
    else
        docker run -d --name sing-box -p 5000:5000 sing-box:latest python main.py --template_index=$template_index "$subscription_url"
    fi
}

# 检查服务状态
check_service() {
    local deploy_type="$1"
    echo "等待服务启动..."
    for i in {1..30}; do
        if curl -s http://localhost:5000 &> /dev/null; then
            echo -e "${GREEN}服务已成功启动并可访问${NC}"
            return 0
        fi
        sleep 1
        echo -n "."
    done
    
    echo -e "\n${RED}服务启动失败，查看日志:${NC}"
    if [ "$deploy_type" = "python" ]; then
        tail -n 20 sing-box.log
    else
        docker logs sing-box
    fi
    return 1
}

# 检查Python环境
check_python_env() {
    echo "检查Python环境..."
    if ! command -v python3 &> /dev/null; then
        echo -e "${BLUE}Python3未安装，是否安装？[Y/n]${NC}"
        read -r install_python
        if [[ $install_python =~ ^[Yy]$ ]] || [[ -z $install_python ]]; then
            echo "安装Python环境..."
            apt-get update
            apt-get install -y python3 python3-pip python3-venv python3-full python-is-python3
            if [ $? -ne 0 ]; then
                echo -e "${RED}Python安装失败${NC}"
                return 1
            fi
        else
            echo "取消安装"
            return 1
        fi
    fi
    return 0
}

# 检查Docker环境
check_docker_env() {
    echo "检查Docker环境..."
    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Docker未安装，是否安装？[Y/n]${NC}"
        read -r install_docker
        if [[ $install_docker =~ ^[Yy]$ ]] || [[ -z $install_docker ]]; then
            echo "安装Docker..."
            curl -fsSL https://get.docker.com | sh
            if [ $? -ne 0 ]; then
                echo -e "${RED}Docker安装失败${NC}"
                return 1
            fi
        else
            echo "取消安装"
            return 1
        fi
    fi
    return 0
}

# 选择部署方式
select_deploy_type() {
    while true; do
        echo -e "${GREEN}请选择部署方式:${NC}"
        echo "1) Python直接部署"
        echo "2) Docker部署"
        read -p "请输入选择(1-2): " choice
        
        case $choice in
            1)
                if check_python_env; then
                    echo "Python环境检查通过"
                    return 1
                else
                    echo -e "${RED}Python环境检查失败，请选择其他部署方式或修复环境${NC}"
                    continue
                fi
                ;;
            2)
                if check_docker_env; then
                    echo "Docker环境检查通过"
                    return 2
                else
                    echo -e "${RED}Docker环境检查失败，请选择其他部署方式或修复环境${NC}"
                    continue
                fi
                ;;
            *)
                echo -e "${RED}无效的选择，请重新输入${NC}"
                continue
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    echo "使用方法: $0 [选项]"
    echo "选项:"
    echo "  -t, --type      部署类型 (python 或 docker)"
    echo "  -s, --sub       订阅地址"
    echo "  -m, --template  模板索引 (1-6，默认4)"
    echo "  -h, --help      显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 --type python --sub https://example.com/sub"
    echo "  $0 --type docker --sub https://example.com/sub --template 4"
}

# 主流程
main() {
    # 解析命令行参数
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t|--type)
                deploy_choice="$2"
                shift 2
                ;;
            -s|--sub)
                subscription_url="$2"
                shift 2
                ;;
            -m|--template)
                template_choice="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 如果没有指定部署类型，进入交互模式
    if [ -z "$deploy_choice" ]; then
        # 检查是否在终端中运行
        if [ -t 0 ]; then
            select_deploy_type
            deploy_type=$?
        else
            echo "请指定部署类型: --type python 或 --type docker"
            exit 1
        fi
    else
        # 根据命令行参数设置部署类型
        case "$deploy_choice" in
            python)
                if check_python_env; then
                    echo "Python环境检查通过"
                    deploy_type=1
                else
                    exit 1
                fi
                ;;
            docker)
                if check_docker_env; then
                    echo "Docker环境检查通过"
                    deploy_type=2
                else
                    exit 1
                fi
                ;;
            *)
                echo "无效的部署类型: $deploy_choice"
                show_help
                exit 1
                ;;
        esac
    fi

    # 1. 清理环境
    cleanup
    
    # 2. 克隆仓库
    echo -e "${BLUE}开始部署 sing-box-subscribe...${NC}"
    if ! command -v git &> /dev/null; then
        echo "安装git..."
        apt-get update && apt-get install -y git
    fi
    git clone https://github.com/bendusy/sing-box-subscribe.git
    cd sing-box-subscribe
    
    # 3. 获取必要参数
    select_template
    template_index=$?
    subscription_url=$(get_subscription_url)
    
    # 4. 部署环境
    case $deploy_type in
        1)
            deploy_python
            deploy_type="python"
            ;;
        2)
            deploy_docker
            deploy_type="docker"
            ;;
        *)
            echo "无效的部署类型"
            exit 1
            ;;
    esac
    
    # 5. 启动服务
    start_service "$deploy_type" "$template_index" "$subscription_url"
    
    # 6. 检查服务状态
    if ! check_service "$deploy_type"; then
        echo -e "${RED}服务启动失败，请检查日志并重试${NC}"
        exit 1
    fi
    
    # 7. 显示服务信息
    SERVER_IP=$(get_ip)
    SHARE_URL=$(generate_share_url "$SERVER_IP" "$subscription_url" "$template_index")
    
    echo -e "\n${GREEN}部署成功!${NC}"
    echo -e "${BLUE}本地访问地址: http://${SERVER_IP}:5000${NC}"
    echo -e "${GREEN}分享URL (可直接导入客户端):${NC}"
    echo -e "${BLUE}$SHARE_URL${NC}"
    
    # 8. 显示管理命令
    echo -e "\n${GREEN}服务管理命令:${NC}"
    if [ "$deploy_type" = "python" ]; then
        echo "启动服务: ./start.sh"
        echo "停止服务: pkill -f 'python main.py'"
        echo "查看日志: tail -f sing-box.log"
    else
        echo "启动服务: docker start sing-box"
        echo "停止服务: docker stop sing-box"
        echo "查看日志: docker logs -f sing-box"
    fi
    echo "重新部署: bash deploy.sh"
}

# 执行主流程
main "$@" 