#!/usr/bin/env bash
set -euo pipefail

# SP証明書/秘密鍵 生成スクリプト（有効期限10年）
SP_HOST="${SP_HOST:-sp.example.com}"
OUT_DIR="${OUT_DIR:-/opt/shibboleth-sp/certs}"
KEY_PATH="${KEY_PATH:-${OUT_DIR}/sp-key.pem}"
CERT_PATH="${CERT_PATH:-${OUT_DIR}/sp-cert.pem}"
DAYS="${DAYS:-3650}"

if ! command -v openssl >/dev/null 2>&1; then
  echo "[gen-sp-cert] エラー: openssl が見つかりません。" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

if [[ -f "${KEY_PATH}" || -f "${CERT_PATH}" ]]; then
  echo "[gen-sp-cert] エラー: 既存ファイルがあります。上書き回避のため中断します。" >&2
  echo "[gen-sp-cert] KEY_PATH=${KEY_PATH}" >&2
  echo "[gen-sp-cert] CERT_PATH=${CERT_PATH}" >&2
  exit 1
fi

openssl req -x509 -newkey rsa:3072 -sha256 -nodes \
  -days "${DAYS}" \
  -subj "/CN=${SP_HOST}" \
  -keyout "${KEY_PATH}" \
  -out "${CERT_PATH}"

chmod 600 "${KEY_PATH}"
chmod 644 "${CERT_PATH}"

echo "[gen-sp-cert] 生成完了"
echo "[gen-sp-cert] KEY_PATH=${KEY_PATH}"
echo "[gen-sp-cert] CERT_PATH=${CERT_PATH}"
echo "[gen-sp-cert] 有効期限(日)=${DAYS}"
