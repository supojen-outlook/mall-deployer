# ============================================
# Ansible 部署 Makefile
# 支持 staging 和 production 环境切换
# ============================================

# 默认环境
ENV ?= staging
INVENTORY_FILE = inventory/$(ENV)/hosts.yml

# 颜色定义
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
RED := \033[0;31m
NC := \033[0m

# Vault 密码文件（如果存在则自动使用）
VAULT_FILE := .vault-pass
ifeq ($(wildcard $(VAULT_FILE)),$(VAULT_FILE))
    VAULT_ARGS := --vault-password-file=$(VAULT_FILE)
else
    VAULT_ARGS := --ask-vault-pass
endif

.PHONY: help deploy update-images secrets staging production status goaccess crowdsec-status crowdsec-metrics crowdsec-decisions crowdsec-explain crowdsec-unban

# ============================================
# 主要命令
# ============================================

help:
	@echo ""
	@echo "$(BLUE)╔══════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║                   Ansible 部署工具                          ║$(NC)"
	@echo "$(BLUE)╚══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)环境切换:$(NC)"
	@echo "  $(GREEN)make staging$(NC)                - 切换到 staging 环境"
	@echo "  $(GREEN)make production$(NC)             - 切换到 production 环境"
	@echo ""
	@echo "$(YELLOW)部署:$(NC)"
	@echo "  $(GREEN)make deploy$(NC)                 - 部署到当前环境 (ENV=staging|production)"
	@echo "  $(GREEN)make deploy ENV=production$(NC)  - 指定 production 部署"
	@echo ""
	@echo "$(YELLOW)更新镜像:$(NC)"
	@echo "  $(GREEN)make update-images$(NC)              - 更新 Docker 镜像到最新版本"
	@echo "  $(GREEN)make update-images VERSION=v1.1.0$(NC) - 指定版本更新所有镜像"
	@echo "  $(GREEN)make update-images API_VERSION=v1.2.0 CLIENT_VERSION=v1.1.0$(NC) - 分别指定版本"
	@echo ""
	@echo "$(YELLOW)Secrets 管理:$(NC)"
	@echo "  $(GREEN)make secrets$(NC)                - 编辑当前环境的 secrets.yml"
	@echo "  $(GREEN)make secrets-create$(NC)         - 创建新的 secrets.yml (会覆盖现有文件)"
	@echo "  $(GREEN)make secrets-view$(NC)           - 查看 secrets.yml 内容"
	@echo "  $(GREEN)make secrets-staging$(NC)        - 编辑 staging secrets"
	@echo "  $(GREEN)make secrets-production$(NC)     - 编辑 production secrets"
	@echo ""
	@echo "$(YELLOW)安全監控 (CrowdSec):$(NC)"
	@echo "  $(GREEN)make crowdsec-status$(NC)       - 查看 CrowdSec bouncer 和封鎖名單"
	@echo "  $(GREEN)make crowdsec-metrics$(NC)      - 查看 CrowdSec 詳細指標"
	@echo "  $(GREEN)make crowdsec-decisions$(NC)    - 查看所有封鎖決策"
	@echo "  $(GREEN)make crowdsec-explain IP=x.x.x.x$(NC) - 查看 IP 觸發的規則詳情"
	@echo "  $(GREEN)make crowdsec-unban IP=x.x.x.x$(NC)  - 手動解除 IP 封鎖"
	@echo ""
	@echo "$(YELLOW)其他:$(NC)"
	@echo "  $(GREEN)make add-domain$(NC)             - 添加新域名"
	@echo "  $(GREEN)make vault-setup$(NC)            - 创建 .vault-pass 密码文件"
	@echo "  $(GREEN)make lint$(NC)                   - 检查 playbook 语法"
	@echo "  $(GREEN)make goaccess$(NC)               - 在终端查看 Nginx 日志分析报告"
	@echo "  $(GREEN)make help$(NC)                   - 显示本帮助"
	@echo ""
	@echo "$(YELLOW)当前环境:$(NC) $(GREEN)$(ENV)$(NC)"
	@if [ -f "$(VAULT_FILE)" ]; then \
		echo "$(YELLOW)Vault 密码文件:$(NC) $(GREEN)已配置 (.vault-pass)$(NC)"; \
	else \
		echo "$(YELLOW)Vault 密码文件:$(NC) $(RED)未配置 (将使用交互式密码输入)$(NC)"; \
	fi
	@echo ""

# ============================================
# 环境切换
# ============================================

staging:
	@echo "$(GREEN)✓ 切换到 staging 环境$(NC)"
	@sed -i.bak 's|inventory = inventory/.*|inventory = inventory/staging/hosts.yml|' ansible.cfg 2>/dev/null || true
	@echo "$(BLUE)当前环境: staging$(NC)"

production:
	@echo "$(YELLOW)⚠️ 切换到 production 环境$(NC)"
	@echo "$(YELLOW)确认继续? (y/n)$(NC)"
	@read confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		sed -i.bak 's|inventory = inventory/.*|inventory = inventory/production/hosts.yml|' ansible.cfg 2>/dev/null || true; \
		echo "$(GREEN)✓ 当前环境: production$(NC)"; \
	else \
		echo "$(RED)已取消$(NC)"; \
	fi

# ============================================
# 部署
# ============================================

deploy:
	@echo "$(BLUE)🚀 部署到 $(ENV) 环境...$(NC)"
	ansible-playbook -i $(INVENTORY_FILE) playbooks/site.yml $(VAULT_ARGS)

update-images:
	@echo "$(BLUE)🔄 更新 Docker 镜像...$(NC)"
	@( \
		EXTRA_VARS=""; \
		[ -n "$(VERSION)" ] && EXTRA_VARS="$$EXTRA_VARS -e api_version=$(VERSION) -e client_version=$(VERSION) -e admin_version=$(VERSION)"; \
		[ -n "$(API_VERSION)" ] && EXTRA_VARS="$$EXTRA_VARS -e api_version=$(API_VERSION)"; \
		[ -n "$(CLIENT_VERSION)" ] && EXTRA_VARS="$$EXTRA_VARS -e client_version=$(CLIENT_VERSION)"; \
		[ -n "$(ADMIN_VERSION)" ] && EXTRA_VARS="$$EXTRA_VARS -e admin_version=$(ADMIN_VERSION)"; \
		ansible-playbook -i $(INVENTORY_FILE) playbooks/update-images.yml $(VAULT_ARGS) $$EXTRA_VARS \
	)

add-domain:
	@echo "$(BLUE)🌐 添加新域名到 $(ENV) 环境...$(NC)"
	ansible-playbook -i $(INVENTORY_FILE) playbooks/add-domain.yml $(VAULT_ARGS)

# ============================================
# Secrets 管理
# ============================================

secrets:
	@echo "$(BLUE)🔐 编辑 $(ENV) 环境的 secrets.yml$(NC)"
	ansible-vault edit inventory/$(ENV)/secrets.yml

secrets-create:
	@echo "$(YELLOW)⚠️ 这将创建新的加密文件，现有文件将被覆盖$(NC)"
	@echo "$(YELLOW)确认继续? (y/n)$(NC)"
	@read confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		ansible-vault create inventory/$(ENV)/secrets.yml; \
	else \
		echo "$(RED)已取消$(NC)"; \
	fi

secrets-view:
	@echo "$(BLUE)👁️ 查看 $(ENV) 环境的 secrets.yml$(NC)"
	ansible-vault view inventory/$(ENV)/secrets.yml

secrets-staging:
	@echo "$(BLUE)🔐 编辑 staging secrets.yml$(NC)"
	ansible-vault edit inventory/staging/secrets.yml

secrets-production:
	@echo "$(YELLOW)🔐 编辑 production secrets.yml$(NC)"
	ansible-vault edit inventory/production/secrets.yml

# ============================================
# Vault 密码文件管理
# ============================================

vault-setup:
	@echo "$(BLUE)🔑 创建 Vault 密码文件...$(NC)"
	@echo "$(YELLOW)请输入 Vault 密码:$(NC)"
	@stty -echo; \
	read password; \
	stty echo; \
	echo "$$password" > $(VAULT_FILE); \
	chmod 600 $(VAULT_FILE); \
	echo ""; \
	echo "$(GREEN)✓ 已创建 $(VAULT_FILE) 并设置权限为 600$(NC)"; \
	echo "$(YELLOW)重要：已将 $(VAULT_FILE) 加入 .gitignore$(NC)"
	@touch .gitignore
	@grep -q "^$(VAULT_FILE)$$" .gitignore || echo "$(VAULT_FILE)" >> .gitignore

# ============================================
# 检查和维护
# ============================================

lint:
	@echo "$(BLUE)🔍 检查 playbook 语法...$(NC)"
	ansible-playbook -i $(INVENTORY_FILE) playbooks/site.yml --syntax-check

check:
	@echo "$(BLUE)🔍 运行检查模式 (dry run)...$(NC)"
	ansible-playbook -i $(INVENTORY_FILE) playbooks/site.yml --check $(VAULT_ARGS)

ping:
	@echo "$(BLUE)📡 测试主机连接...$(NC)"
	ansible -i $(INVENTORY_FILE) all -m ping

status: ping

# ============================================
# GoAccess 日志分析
# ============================================

goaccess:
	@echo "$(BLUE)📊 连接到 $(ENV) 环境查看 GoAccess 报告...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "sudo goaccess /var/log/nginx/access.log --log-format=COMBINED --real-time-html" -t 0 --become

# ============================================
# CrowdSec 安全監控
# ============================================

crowdsec-status:
	@echo "$(BLUE)🔒 CrowdSec 狀態檢查...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "cscli bouncers list && echo '---' && cscli decisions list | head -20"

crowdsec-metrics:
	@echo "$(BLUE)🔒 CrowdSec 指標查看...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "cscli metrics"

crowdsec-decisions:
	@echo "$(BLUE)🔒 查看封鎖決策...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "cscli decisions list"

crowdsec-explain:
	@echo "$(BLUE)🔒 查看 IP 詳細觸發規則: $(IP)...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "cscli explain --ip $(IP)"

crowdsec-unban:
	@echo "$(BLUE)🔒 解除封鎖 IP: $(IP)...$(NC)"
	@ansible -i $(INVENTORY_FILE) webservers -m shell -a "cscli decisions delete --ip $(IP)"
