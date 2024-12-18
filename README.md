本地python执行脚本命令：

```
python main.py
```

或者你可以直接带template_index参数选定模板，0表示第一个模板(no flask不支持此参数)

```
python main.py --template_index=0
```

支持Docker

```
docker build --tag 'sing-box' .
docker run -p 5000:5000 sing-box:latest
```

### 一键部署脚本

使用Python部署:
```bash
curl -fsSL https://raw.githubusercontent.com/bendusy/sing-box-subscribe/main/deploy.sh | bash -s python
```

使用Docker部署:
```bash
curl -fsSL https://raw.githubusercontent.com/bendusy/sing-box-subscribe/main/deploy.sh | bash -s docker
```

或者下载脚本后交互式部署:
```bash
wget -O deploy.sh https://raw.githubusercontent.com/bendusy/sing-box-subscribe/main/deploy.sh && chmod +x deploy.sh && ./deploy.sh
```

注意事项:
- 需要root权限执行
- 确保5000端口未被占用
- 脚本会自动配置防火墙规则（如果存在）
- 默认使用 config_template_test 模板
- 如果要使用其他模板:
  1. 停止当前服务
  2. 编辑 start.sh，修改 --template_index 参数（0-5）
  3. 重新启动服务
- 如果无法访问，请检查:
  1. 防火墙是否放行5000端口
  2. 云服务器安全组是否开放5000端口
  3. 查看日志: `tail -f sing-box.log`

可用的配置模板:
1. config_template_groups_rule_set_tun
2. config_template_groups_rule_set_tun_fakeip
3. config_template_no_groups_tun_VN
4. config_template_test (默认)
5. config_template_test_dns
6. sb-config-1.11

部署完成后脚本会自动显示访问地址

### 根据已有的qx，surge，loon，clash规则列表自定义规则集[https://github.com/Toperlock/sing-box-geosite](https://github.com/Toperlock/sing-box-geosite)

### wechat规则集源文件写法：
```json
{
  "version": 1,
  "rules": [
    {
      "domain": [
        "dl.wechat.com",
        "sgfindershort.wechat.com",
        "sgilinkshort.wechat.com",
        "sglong.wechat.com",
        "sgminorshort.wechat.com",
        "sgquic.wechat.com",
        "sgshort.wechat.com",
        "tencentmap.wechat.com.com",
        "qlogo.cn",
        "qpic.cn",
        "servicewechat.com",
        "tenpay.com",
        "wechat.com",
        "wechatlegal.net",
        "wechatpay.com",
        "weixin.com",
        "weixin.qq.com",
        "weixinbridge.com",
        "weixinsxy.com",
        "wxapp.tc.qq.com"
      ]
    },
    {
      "domain_suffix": [
        ".qlogo.cn",
        ".qpic.cn",
        ".servicewechat.com",
        ".tenpay.com",
        ".wechat.com",
        ".wechatlegal.net",
        ".wechatpay.com",
        ".weixin.com",
        ".weixin.qq.com",
        ".weixinbridge.com",
        ".weixinsxy.com",
        ".wxapp.tc.qq.com"
      ]
    },
    {
      "ip_cidr": [
        "101.32.104.4/32",
        "101.32.104.41/32",
        "101.32.104.56/32",
        "101.32.118.25/32",
        "101.32.133.16/32",
        "101.32.133.209/32",
        "101.32.133.53/32",
        "129.226.107.244/32",
        "129.226.3.47/32",
        "162.62.163.63/32"
      ]
    }
  ]
}
```
配置文件添加源文件规则集：
```
{
  "tag": "geosite-wechat",
  "type": "remote",
  "format": "source",
  "url": "https://raw.githubusercontent.com/Toperlock/sing-box-geosite/main/wechat.json",
  "download_detour": "auto"
}
```

