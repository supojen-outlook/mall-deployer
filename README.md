# 小紅帽電商系統自動化部署方案

這個專案幫助我們自動化上版小紅帽的電商系統，使用 Ansible 進行自動化部署到 staging 和 production 環境。透過標準化的部署流程，確保系統的一致性和可靠性。

# Ansible 部署方案

使用 Ansible 自动化部署网站到 staging 和 production 环境。

## 前置要求

- Ansible >= 2.9
- SSH 免密登录目标服务器
- 目标服务器用户具有 sudo 权限

## 目录结构

```
ansible/
├── ansible.cfg              # Ansible 配置
├── files/                   # playbook 级别文件
│   └── keys/                # 生成的密钥（gitignore）
├── inventory/
│   ├── staging/
│   │   ├── hosts.yml        # Staging 主机清单
│   │   ├── group_vars/
│   │   │   └── all.yml    # Staging 普通变量
│   │   ├── secrets.yml      # Staging 敏感变量 (ansible-vault 加密)
│   │   └── secrets.yml.example  # 示例（未加密）
│   └── production/
│       ├── hosts.yml        # Production 主机清单
│       ├── group_vars/
│       │   └── all.yml    # Production 普通变量
│       ├── secrets.yml      # Production 敏感变量 (ansible-vault 加密)
│       └── secrets.yml.example  # 示例（未加密）
├── group_vars/
│   └── all.yml              # 通用变量
├── roles/
│   ├── common/              # 基础配置
│   ├── nginx/               # Nginx 安装配置
│   ├── certbot/             # SSL 证书
│   ├── docker/              # Docker 安装
│   └── app/                 # 应用部署
│       ├── files/
│       │   ├── keygen-tool  # 密钥生成工具
│       │   └── src/         # 网站源文件
│       └── templates/
│           ├── .env.j2      # Docker 环境变量模板
│           └── domain.conf.j2  # 站点配置模板
└── playbooks/
    ├── site.yml             # 完整部署
    └── add-domain.yml       # 添加新域名
```

## 配置步骤

### 1. 配置 Inventory

**注意：** `hosts.yml` 包含服务器 IP/域名，**不应提交到 Git**。已添加到 `.gitignore`。

使用模板创建实际的 inventory 文件：

```bash
# staging 环境
cp inventory/staging/hosts.yml.example inventory/staging/hosts.yml
# 编辑填入实际 IP 或域名
vim inventory/staging/hosts.yml

# production 环境
cp inventory/production/hosts.yml.example inventory/production/hosts.yml
vim inventory/production/hosts.yml
```

**hosts.yml 格式：**
```yaml
all:
  children:
    webservers:
      hosts:
        staging-server:
          ansible_host: 192.168.1.100    # 或域名: staging.example.com
          ansible_user: ubuntu
```

**IP vs 域名选择：**
- **IP**: 直接连接，适合固定 IP 的服务器
- **域名**: 更灵活，IP 变更时无需修改配置

### 2. 配置环境变量

编辑 `group_vars/staging.yml` 或 `group_vars/production.yml`：

```yaml
# 域名
domain: staging.your-domain.com

# 端口配置
client_port: 8081
admin_port: 8082
api_port: 7175
```

### 3. 配置敏感变量（Ansible Vault）

敏感信息（数据库密码、API Key、邮件密码）使用 Ansible Vault 加密存储。

#### 3.1 创建加密的 secrets.yml

**staging 环境：**
```bash
# 创建加密文件（交互式输入密码）
ansible-vault create inventory/staging/secrets.yml

# 或使用密码文件
ansible-vault create --vault-password-file=.vault-pass inventory/staging/secrets.yml
```

**production 环境：**
```bash
ansible-vault create inventory/production/secrets.yml
```

#### 3.2 secrets.yml 格式

参考 `secrets.yml.example`：

```yaml
---
# 数据库连接字串
db_connection_string: "Host=your-db-host;Port=5432;Database=app;Username=user;Password=your-password"

# 邮件配置
email_sender_name: "Your Site Name"
email_account: "your-email@gmail.com"
email_password: "your-app-password"

# S3 / DigitalOcean Spaces 配置
s3_access_key: "your-access-key"
s3_secret: "your-secret-key"
s3_url: "https://your-bucket.sgp1.digitaloceanspaces.com"
s3_cdn: "https://your-cdn-url"
```

#### 3.3 管理加密文件

```bash
# 编辑已加密的文件
ansible-vault edit inventory/staging/secrets.yml

# 查看加密文件内容（不解密保存）
ansible-vault view inventory/staging/secrets.yml

# 重新加密（更改密码）
ansible-vault rekey inventory/staging/secrets.yml

# 解密文件
ansible-vault decrypt inventory/staging/secrets.yml

# 加密现有文件
ansible-vault encrypt inventory/staging/secrets.yml
```

#### 3.4 使用密码文件（推荐）

创建密码文件避免每次输入：

```bash
# 创建密码文件（加入 .gitignore！）
echo "your-vault-password" > .vault-pass
chmod 600 .vault-pass

# 编辑 ansible.cfg 自动使用
echo "[defaults]" >> ansible.cfg
echo "vault_password_file = .vault-pass" >> ansible.cfg
```

**重要：** 将 `.vault-pass` 加入 `.gitignore`：
```bash
echo ".vault-pass" >> .gitignore
```

## 执行部署

### 方式一：使用 Makefile（推荐）

```bash
cd ansible

# 查看所有可用命令
make help

# 设置 Vault 密码文件（可选，避免每次输入密码）
make vault-setup

# 编辑 staging/production 的 secrets
make secrets-staging
make secrets-production

# 部署到 staging
make staging
make deploy

# 或一键部署到 production
make deploy ENV=production

# 添加新域名
make add-domain
```

### 方式二：使用原始 ansible-playbook 命令

```bash
cd ansible

# Staging 环境（带 vault 密码）
ansible-playbook -i inventory/staging playbooks/site.yml --ask-vault-pass

# 或使用密码文件
ansible-playbook -i inventory/staging playbooks/site.yml --vault-password-file=.vault-pass

# Production 环境
ansible-playbook -i inventory/production playbooks/site.yml --ask-vault-pass

# 添加新域名
ansible-playbook -i inventory/staging playbooks/add-domain.yml --ask-vault-pass
```

**如果配置了 ansible.cfg 的 `vault_password_file`，则无需 `--ask-vault-pass`：**
```bash
ansible-playbook -i inventory/staging playbooks/site.yml
```

### 添加新域名

```bash
# Staging 环境
ansible-playbook -i inventory/staging playbooks/add-domain.yml
# 然后输入新域名

# Production 环境
ansible-playbook -i inventory/production playbooks/add-domain.yml
```

### 单独执行某些 roles

```bash
# 只部署 Nginx
ansible-playbook -i inventory/staging playbooks/site.yml --tags nginx

# 只部署应用
ansible-playbook -i inventory/staging playbooks/site.yml --tags app
```

## GoAccess 即時監控

部署後自動啟用即時日誌分析，透過 WebSocket 即時更新訪問數據。

### 訪問統計頁面

```
https://your-domain.com/stats.html
```

- 需要 Basic Auth 認證（帳密在 `secrets.yml` 設定）
- 頁面右下角綠色圓點表示 WebSocket 連線正常
- 數據即時更新，無需重新整理頁面

### 配置變數

在 `inventory/{staging,production}/group_vars/all.yml`：

```yaml
# GoAccess 配置
goaccess_ws_port: 7890
goaccess_stats_path: /var/www/html/stats.html
```

在 `inventory/{staging,production}/secrets.yml`：

```yaml
# GoAccess 統計頁面認證
goaccess_admin_user: "admin"
goaccess_admin_password: "your-secure-password"
```

### 服務管理

```bash
# 檢查服務狀態
sudo systemctl status goaccess

# 查看即時日誌
sudo journalctl -u goaccess -f

# 重啟服務
sudo systemctl restart goaccess
```

### 地理位置分析 (GeoIP)

GoAccess 整合 MaxMind GeoLite2-City 資料庫，可分析訪問者的國家/城市資訊。

**前置需求**：
1. 前往 [MaxMind](https://www.maxmind.com) 註冊免費帳號
2. 取得 **Account ID** 和 **License Key**
3. 填入 `inventory/{staging,production}/secrets.yml`：

```yaml
# MaxMind GeoIP 配置
maxmind_account_id: "123456"
maxmind_license_key: "your_license_key"
```

**自動更新**：
- 每週一凌晨 3 點自動下載最新 GeoIP 資料庫
- 更新後自動重啟 GoAccess 服務
- 手動更新：`sudo geoipupdate && sudo systemctl restart goaccess`

**資料位置**：`/var/lib/GeoIP/GeoLite2-City.mmdb`

**注意事項**：
- IP 定位精確度約為「城市」層級，4G/5G 用戶可能顯示電信商機房位置
- VPN/Proxy 會影響定位準確性
- GeoLite2 採用 CC BY-SA 4.0 授權

## 注意事项

- 首次运行前请确保目标服务器已配置 SSH 免密登录
- `.env` 文件包含敏感信息，请勿提交到 Git
- 密钥生成会在本地执行（需要 keygen-tool 存在）
- SSL 证书会自动续期（通过 cron 任务）

## GNU 授權條款

本程式為自由軟體；您可依據 GNU 通用公共授權條款（GNU General Public License）第三版或（您選擇的）任何後續版本的條款，重新散布及/或修改它。

本程式發布的目的是希望它有用，但不含任何擔保；甚至不含對適銷性或特定目的適用性的暗示擔保。詳情請參閱 GNU 通用公共授權條款。

您應該已收到本程式隨附的 GNU 通用公共授權條款；如果沒有，請參閱 <https://www.gnu.org/licenses/>。

---

**專案維護者**：小紅帽電商系統開發團隊  
**最後更新**：2026年
