# docker-squid-sslbump

HTTPS通信可視化用のテストコンテナ＋起動用スクリプト

<br>

### 概要
- Dockerで, [Squid](https://www.squid-cache.org/)のSSL Bumpを用いてHTTPS通信のリクエストパス等を可視化するもの

- 実用性はなく, 2025年7月の最新環境でSquid + SSL Bumpが動いた記録および検証用のリポジトリ

  - ルーティングやSquidの設定は「ひとまずこれで動いた」一例に過ぎません

- 元々はキャッシュ用プロキシサーバ検討時の副産物. 下記の理由でキャッシュにはほぼ使えません🙇‍♂️

  - SquidがキャッシュできるWebコンテンツは限定的 (レスポンスヘッダにLast-Modifiedがある等)

  - クライアント端末のOS/ブラウザ等にTLS証明書をインストールする必要がある

<br>

### 構成

  ```mermaid
  flowchart LR
      r1{{HTTP/HTTPS<br>Request}} <--> w1(Wi-Fi Hotspot)
      subgraph Host PC
          w1
          subgraph docker
              s(Squid)
          end
          r2{{HTTP/HTTPS<br>Request}} <--> w2(Wired LAN)
      end
      w1 <--> s
      s <--> w2
      w2 <--> i((Internet))
  ```

- ホストPC (Ubuntu 24.04)

  ```sh
  uname -v
  # #24~24.04.3-Ubuntu SMP PREEMPT_DYNAMIC Mon Jul  7 16:39:17 UTC 2

  docker --version
  # Docker version 28.3.2, build 578ccf6

  openssl version
  # OpenSSL 3.0.13 30 Jan 2024 (Library: OpenSSL 3.0.13 30 Jan 2024)

  iptables --version
  # iptables v1.8.10 (nf_tables)
  ```

- コンテナ (Ubuntu/squid)

   ```sh
   uname -a
   # Linux squid 6.14.0-24-generic #24~24.04.3-Ubuntu SMP PREEMPT_DYNAMIC Mon Jul  7 16:39:17 UTC 2 x86_64 x86_64 x86_64 GNU/Linux

   squid -v
   # Squid Cache: Version 6.13
   ```

<br>

### 使用手順

1. 本リポジトリを任意の場所にcloneし, リポジトリのトップに移動

   ```sh
   git clone git@github.com:ec22s/docker-squid-sslbump.git
   cd docker-squid-sslbump
   ```

2. TLS証明書(いわゆるオレオレ証明書)を作成

   ```sh
   openssl req -new -newkey rsa:2048 -days {証明書の有効日数} -nodes -x509 \
     -subj '/C=JP' \
     -keyout ./conf/squid_bump.key \
     -out ./conf/squid_bump.crt
   ```

3. LAN側のNIC名を `ip a` 等で確認, 起動用スクリプト `start.sh` に設定

   https://github.com/ec22s/docker-squid-sslbump/blob/070c3fe3ed99e357c57f518553b51e18625d2487/start.sh#L1-L2

   - このNICがホットスポットになって他のNICのインターネット接続を共有していれば, スクリプトの `iptables` 設定によってホットスポット経由のHTTP・HTTPSアクセスがSquidへ転送されます

   - ホストPCからのHTTP・HTTPSアクセスはSquidを経由しません

4. 起動・終了

   ```sh
   sudo ./start.sh
   ```

   - 下記の順で起動処理が走ります

     - コンテナが起動済みならいったん終了, ボリュームを消去

     - `iptables` でルーティングを設定

     - コンテナを起動 (詳細は `Dockerfile` と `docker-compose.yml` を参照)

     - 問題なければ最後に `docker ps -a` の出力を表示

   - 終了は `docker compose down` (コンテナ内部で作られたログやキャッシュは消えます)

     - 設定を変えずに再起動する場合 `docker compose up -d`

5. 状況確認

   ```sh
   # 各ポート
   netstat -ntl

   # iptables
   sudo iptables -L -t nat
   cat /etc/iptables/rules.v4

   # Squidのアクセスログ
   docker exec -it squid tail -f /var/log/squid/access.log
   ```

<br>

### 動作確認した手順

- ホストPCの有線LANをインターネットに接続

- ホストPCの無線LANをホットスポットに設定 (インターネット接続を共有)

- TLS証明書をホストPC上で作成し `conf` ディレクトリに保存

- 無線LANのNIC名を `start.sh` に設定

- コンテナ起動

- 他のPCに `conf/squid_bump.crt` をコピー, ホットスポットに接続してコマンド実行

  ```sh
  # HTTPサイトに初回アクセス
  curl http://abehiroshi.la.coocan.jp/

  # 同じHTTPサイトにもう一度アクセス (*1)
  curl http://abehiroshi.la.coocan.jp/

  # TLS証明書を利用してHTTPSサイトに初回アクセス
  curl --cacert squid_bump.crt https://www.saitama-u.ac.jp/entrance/

  # 同じHTTPSサイトにもう一度アクセス (*2)
  curl --cacert squid_bump.crt https://www.saitama-u.ac.jp/entrance/
  ```

- 上記に対するSquidのアクセスログ確認

  ```
  *1) ... TCP_MEM_HIT/200 855 GET http://abehiroshi.la.coocan.jp/ - HIER_NONE/- text/html
  *2) ... TCP_HIT/200 115349 GET https://www.saitama-u.ac.jp/entrance/ - HIER_NONE/- text/html
  ```

  - HTTP・HTTPSともにキャッシュがありヒットしたことが分かる

  - HTTPS通信のGETリクエストが可視化されている (本来はFQDNへのCONNECTリクエストしか見えない)

<br>

- ただし多くのWebサイトではSquidがキャッシュできない. レスポンスヘッダに `Last-Modified` がない等の理由で, リクエストの都度コンテンツを取得してしまう

- 通常のHTTPSリクエストは証明書エラーで失敗する

- 接続したPCの常駐プロセス (ルート証明書取得等) が定期的にHTTPSリクエストを送っていると, そのエラーがSquidのアクセスログに大量に記録される

<br>

以上
