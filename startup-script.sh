#!/bin/bash
#
# 這個腳本會在 VM 啟動時自動運行。
# 它會安裝和設定 Docker 和 Docker Compose。
#

echo "--- 更新系統套件 ---"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "--- 安裝必要的工具，用於下載和驗證 Docker ---"
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

echo "--- 加入 Docker 的官方 GPG 金鑰 ---"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "--- 設定 Docker 的 APT 軟體庫 ---"
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "--- 再次更新套件索引 ---"
sudo apt-get update -y

echo "--- 安裝 Docker 引擎和相關工具 ---"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "--- 啟動 Docker 服務並設定開機自啟 ---"
sudo systemctl start docker
sudo systemctl enable docker

echo "--- 將當前使用者加入 docker 群組，以便不需要 sudo 就可以運行 Docker ---"
sudo usermod -aG docker ${USER}

echo "--- 顯示 Docker 版本以確認安裝成功 ---"
docker --version

echo "--- 顯示 Docker Compose 版本以確認安裝成功 ---"
docker compose version

echo "--- 清理不必要的套件 ---"
sudo apt-get autoremove -y

echo "--- 腳本執行完畢 ---"