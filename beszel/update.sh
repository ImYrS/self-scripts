#!/bin/bash

# 检查是否为 root 权限
if [ "$(id -u)" -ne 0 ]; then
    sudo su
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ 未能自动切换至 root 权限，请先切换至 root 用户再运行更新脚本。"
        exit 1
    fi
fi
echo "✔ 权限检查通过，开始更新任务"

# 判断 beszel-agent 的运行方式，并执行相应操作
if docker ps &> /dev/null; then
    echo "✔ beszel-agent 本机运行方式为 Docker"

    # 获取工作目录
    WORKING_DIR=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' "beszel-agent")
    
    if [[ -n "$WORKING_DIR" ]]; then
        echo "✔ 已定位至 Docker Compose 目录: $WORKING_DIR"
    else
        echo "❌ 未找到 Docker 实例或工作目录，请尝试手动执行更新。"
        exit 1
    fi
    
    echo "准备拉取最新版本并重新部署"
    cd $WORKING_DIR || exit 1
    docker compose pull
    docker compose up -d
    echo "✔ 运行完成，请根据日志自检"
else
    echo "✔ beszel-agent 本机运行方式为 Binary"
    
    # 停止服务
    echo "停止服务中..."
    service beszel-agent stop

    # 下载最新的二进制程序
    echo "正在下载最新版本并解压"
    curl -sL "https://ghp.ci/https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_$(uname -s)_$(uname -m | sed 's/x86_64/amd64/' | sed 's/armv7l/arm/' | sed 's/aarch64/arm64/').tar.gz" | tar -xz -O beszel-agent | tee ./beszel-agent >/dev/null
    chmod +x beszel-agent

    # 备份旧程序并覆盖
    if [ -f /opt/beszel-agent/beszel-agent ]; then
        mv /opt/beszel-agent/beszel-agent /opt/beszel-agent/beszel-agent.bak
    fi
    mv ./beszel-agent /opt/beszel-agent/beszel-agent
    echo "✔ 已覆盖更新，旧版本程序保存在 /opt/beszel-agent/beszel-agent.bak"

    # 重新启动服务
    echo "重启 Service 中"
    service beszel-agent start

    # 检查服务状态
    if service beszel-agent status | grep -q "running"; then
        echo "✔ 已成功升级并重启服务"
    else
        echo "服务重启失败，请检查日志。"
    fi
fi
