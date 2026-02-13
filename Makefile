APP := shibboleth-sp
INSTALL_DIR := /opt/$(APP)
SERVICE_DIR := $(INSTALL_DIR)/app
LOG_BASE_DIR := $(INSTALL_DIR)/logs
METADATA_DIR := $(INSTALL_DIR)/metadata
CERTS_DIR := $(INSTALL_DIR)/certs
SOURCE_DIR := $(CURDIR)

.PHONY: help
help: ## ヘルプを表示する。
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: init
init: ## 配備先ディレクトリとログ/証明書/メタデータディレクトリを作成する。
	sudo mkdir -p $(INSTALL_DIR) && sudo chown ec2-user:ec2-user $(INSTALL_DIR)
	mkdir -p $(SERVICE_DIR)
	mkdir -p $(LOG_BASE_DIR)/shibboleth $(LOG_BASE_DIR)/httpd
	mkdir -p $(METADATA_DIR) $(CERTS_DIR)

.PHONY: deploy
deploy: ## 当該機能を配備する。
	rsync -a --delete \
		--exclude '.git' \
		--exclude '.gitignore' \
		--exclude '.DS_Store' \
		$(SOURCE_DIR)/ $(SERVICE_DIR)/
	$(MAKE) build

.PHONY: build
build: ## 当該機能で利用するDockerイメージをビルドする。
	cd $(SERVICE_DIR) && docker compose build
	docker image prune -f

.PHONY: start
start: ## 当該機能を起動する。
	cd $(SERVICE_DIR) && docker compose up -d

.PHONY: stop
stop: ## 当該機能を停止する。
	cd $(SERVICE_DIR) && docker compose down

.PHONY: log
log: ## ログを表示する。
	cd $(SERVICE_DIR) && docker compose logs -f

.PHONY: gen_sp_metadata
gen_sp_metadata: ## SP証明書からSPメタデータを生成する。
	cd $(SOURCE_DIR) && ./scripts/gen-sp-metadata.sh

.PHONY: erase
erase: ## 当該機能で利用するDockerイメージを削除する。
	(cd $(SERVICE_DIR) && docker compose down --rmi all || exit 0)
	docker image prune -f

################################################################################
# !!! DANGER !!!
################################################################################
.PHONY: CLEAN
CLEAN: ## (危険) 当該機能を除却する。(データは削除しない)
	$(MAKE) erase
	sudo rm -rf $(INSTALL_DIR)
