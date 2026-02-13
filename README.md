# Shibboleth SP on EC2 Docker (Sample)

このリポジトリは、**EC2 上の Docker コンテナ**として Shibboleth SP (Apache + mod_shib) を導入するための最小サンプルです。  
要件として挙がっている以下に対応します。

- SP-Initiated SSO
- IdP-Initiated SSO
- SP-Initiated SLO
- IdP-Initiated SLO
- IdP から受け取った `userid` Attribute を `X-USER-ID` ヘッダとしてアプリへ連携

---

## 1. 構成

```text
.
├── Dockerfile
├── docker-compose.yml
├── Makefile
├── apache/
│   └── shib.conf
├── html/
│   └── secure/index.html
├── scripts/
│   └── entrypoint.sh
└── shibboleth/
    ├── shibboleth2.xml
    ├── attribute-map.xml
    ├── attribute-policy.xml
    └── metadata/idp-metadata.xml
```

- `Dockerfile`: Amazon Linux 2023 ベースの Shibboleth SP コンテナ定義。
- `docker-compose.yml`: `shibsp`(Apache+Shibboleth SP) の起動定義。`/opt/shibboleth-sp/{metadata,certs,logs}` をコンテナへマウントして運用。
- `Makefile`: `make init`～`make deploy`～`make start` で `/opt/shibboleth-sp` 配下に配備/起動するタスクランナー。
- `apache/shib.conf`: SPハンドラ公開、`/secure` 認証、`userid` → `X-USER-ID` ヘッダ変換、ホストOS上Webアプリへの転送設定。
- `html/secure/index.html`: 最小限の保護ページ。
- `scripts/entrypoint.sh`: 証明書存在確認、Apacheの8080待受化、`shibd`/`httpd` 起動。
- `shibboleth/shibboleth2.xml`: SP本体設定（SSO/SLO、メタデータ、属性抽出/フィルタ）。
- `shibboleth/attribute-map.xml`: SAML Attribute 名/OID と SP属性IDのマッピング。
- `shibboleth/attribute-policy.xml`: SPで利用可能な属性の許可ポリシー。
- `shibboleth/metadata/idp-metadata.xml`: IdPメタデータ配置ファイル（置換前提）。

---

## 2. 前提条件

- EC2 (Amazon Linux 2023)
- Docker / Docker Compose は導入済み
- ホストOS上のWebアプリが `localhost:8081` で常駐起動済み
- このリポジトリをEC2上へ pull 済み

---

## 3. アーキテクチャ

- ALB からパスルーティングされたリクエストを **EC2:8081** で受信
- `docker-compose.yml` では `8081:8080` で公開し、コンテナ内の Apache + Shibboleth SP は **8080** で待受
- `/secure` へアクセスした場合、Shibboleth認証後に **ホストOS上のWebアプリ（localhost:8081）** へプロキシ
- EC2 は1台構成。将来拡張を見据え ALB スティッキーセッションを利用

---

## 4. 設定の置換ポイント

### 4.1 SP entityID と IdP entityID
- `shibboleth/shibboleth2.xml`
  - `ApplicationDefaults@entityID`
  - `<SSO entityID="...">`

### 4.2 IdP メタデータ
- `shibboleth/metadata/idp-metadata.xml` を IdP の実メタデータに置換
- `make deploy` 後、`/opt/shibboleth-sp/metadata` へ配備されるため、必要に応じて同ディレクトリを直接更新

### 4.3 userid 属性の OID/Name
- `shibboleth/attribute-map.xml` の `id="userid"` の Attribute `name` を実値に置換

### 4.4 SP 証明書
- 証明書は手動配置前提
- `sp-key.pem` と `sp-cert.pem` を `/opt/shibboleth-sp/certs` に配置
- 未配置の場合、`entrypoint.sh` は起動を中断

---

## 5. Makefile による導入・起動手順

`make` コマンドで `/opt/shibboleth-sp` 配下へ配置して運用します。

```bash
make init
make deploy
make start
```

主なタスク:

- `make init`: `/opt/shibboleth-sp`、`/opt/shibboleth-sp/app`、`/opt/shibboleth-sp/{metadata,certs}`、`/opt/shibboleth-sp/logs/{shibboleth,httpd}` を作成
- `make deploy`: リポジトリ内容を `/opt/shibboleth-sp/app` に同期し、`make build` を実行
- `make build`: Docker イメージをビルド
- `make start`: コンテナ起動
- `make stop`: コンテナ停止
- `make log`: ログ表示
- `make erase`: コンテナ/イメージ削除
- `make CLEAN`: `/opt/shibboleth-sp` を削除（危険）

---

## 6. 起動後の確認 (ALB経由)

- 保護URL: `https://<ALB_DNS_NAME>/secure`
- Session確認: `https://<ALB_DNS_NAME>/Shibboleth.sso/Session`
- SPメタデータ: `https://<ALB_DNS_NAME>/Shibboleth.sso/Metadata`

---

## 7. Attribute を HTTP ヘッダに転送

`apache/shib.conf` で以下を設定済みです。

```apache
RequestHeader unset X-USER-ID
RequestHeader set X-USER-ID "%{userid}e" env=userid
```

- `unset` で外部入力ヘッダを破棄（偽装対策）
- `userid` がある場合のみ `X-USER-ID` を付与

---

## 8. 大容量ファイル転送時の注意点（要件反映）

本サンプルでは、Apache を「Shibboleth 認証ゲート + リバースプロキシ」として利用する前提で、以下を反映しています。

- タイムアウト（5分）
  - `Timeout 300`
  - `ProxyTimeout 300`
  - `KeepAlive On`
  - `KeepAliveTimeout 30`
- アップロード制限
  - `/secure/upload` に `LimitRequestBody 0`（無制限）を設定
  - 実運用ではアプリ側上限（multipart設定等）と必ず整合を取る
- 大容量/バイナリ配信時の圧縮抑止
  - `zip/gz/tar/7z/pdf/mp4...` で `no-gzip=1`
- 切り分けしやすいログ
  - AccessLog に `D=%D`（処理時間[μs]）を出力

加えて、長時間転送では **ALB idle timeout** も Apache と同オーダーで調整してください。  
Apache 側を延長しても ALB の idle timeout が短いと転送が途中切断されます。

---

## 9. ログ確認

```bash
make log
```

ホストOSへ永続化されるログ:

- `/opt/shibboleth-sp/logs/shibboleth/shibd.log`
- `/opt/shibboleth-sp/logs/httpd/error_log`

---

## 10. 注意

- `idp-metadata.xml` はプレースホルダのため、そのままでは認証できません。
- 署名付きメタデータや証明書ローテーションは本番要件に合わせて強化してください。
- SLOの動作は IdP 側の Binding/NameID/署名ポリシーとの整合が必要です。
