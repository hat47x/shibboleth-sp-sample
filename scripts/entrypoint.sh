#!/usr/bin/env bash
set -euo pipefail

# 証明書は手動配置前提（未配置なら起動しない）
if [[ ! -f /etc/shibboleth/certs/sp-key.pem || ! -f /etc/shibboleth/certs/sp-cert.pem ]]; then
  echo "[entrypoint] エラー: /etc/shibboleth/certs/sp-key.pem または sp-cert.pem がありません。" >&2
  echo "[entrypoint] 証明書を手動配置してから再起動してください。" >&2
  exit 1
fi

# ALB パスルーティング構成: Apache + SP は 8080 で待受
sed -ri 's/^Listen 80$/Listen 8080/' /etc/httpd/conf/httpd.conf

mkdir -p /var/log/httpd /var/log/shibboleth

echo "[entrypoint] shibd を起動します..."
/usr/sbin/shibd -F &

sleep 2

echo "[entrypoint] httpd を起動します..."
exec /usr/sbin/httpd -D FOREGROUND
