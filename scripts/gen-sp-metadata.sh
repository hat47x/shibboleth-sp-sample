#!/usr/bin/env bash
set -euo pipefail

# SPメタデータ生成スクリプト
# - 証明書(sp-cert.pem)からSPメタデータを生成
# - KeyDescriptorを signing / encryption に分割
# - BindingはShibboleth SPの標準生成結果を利用

SP_HOST="${SP_HOST:-sp.example.com}"
BASE_URL="${BASE_URL:-https://${SP_HOST}}"
ENTITY_ID="${ENTITY_ID:-${BASE_URL}/shibboleth}"
CERT_PEM="${CERT_PEM:-/opt/shibboleth-sp/certs/sp-cert.pem}"
OUT_XML="${OUT_XML:-./sp-metadata.xml}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[gen-sp-metadata] エラー: python3 が見つかりません。" >&2
  exit 1
fi

if [[ ! -f "${CERT_PEM}" ]]; then
  echo "[gen-sp-metadata] エラー: 証明書が見つかりません: ${CERT_PEM}" >&2
  exit 1
fi

METAGEN_CMD=""
if command -v shib-metagen >/dev/null 2>&1; then
  METAGEN_CMD="shib-metagen"
elif [[ -x /etc/shibboleth/metagen.sh ]]; then
  METAGEN_CMD="/etc/shibboleth/metagen.sh"
else
  echo "[gen-sp-metadata] エラー: shib-metagen または /etc/shibboleth/metagen.sh が見つかりません。" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

# メタデータ原型を生成（ACS/SLO/bindingはShibboleth SP標準）
"${METAGEN_CMD}" \
  -c "${CERT_PEM}" \
  -h "${SP_HOST}" \
  -e "${ENTITY_ID}" \
  > "${tmp}"

python3 - "${tmp}" "${OUT_XML}" <<'PY'
import sys
import xml.etree.ElementTree as ET
from copy import deepcopy

src, dst = sys.argv[1], sys.argv[2]

NS = {
    "md": "urn:oasis:names:tc:SAML:2.0:metadata",
    "ds": "http://www.w3.org/2000/09/xmldsig#",
}
for k, v in NS.items():
    ET.register_namespace(k, v)

root = ET.parse(src).getroot()
sp = root.find("md:SPSSODescriptor", NS)
if sp is None:
    raise SystemExit("SPSSODescriptor が見つかりません")

kd = sp.find("md:KeyDescriptor", NS)
if kd is None:
    raise SystemExit("KeyDescriptor が見つかりません")

sp.remove(kd)
kd_sign = deepcopy(kd)
kd_sign.set("use", "signing")
kd_enc = deepcopy(kd)
kd_enc.set("use", "encryption")
sp.insert(0, kd_enc)
sp.insert(0, kd_sign)

ET.ElementTree(root).write(dst, encoding="utf-8", xml_declaration=True)
print(f"[gen-sp-metadata] 生成完了: {dst}")
PY

echo "[gen-sp-metadata] entityID=${ENTITY_ID}"
echo "[gen-sp-metadata] 注意: IdPへ登録前に生成内容（ACS/SLO/証明書）を確認してください。"
