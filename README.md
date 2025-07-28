# docker-squid-sslbump

HTTPS通信可視化用のテストコンテナ

<br>

### 概要
- Dockerで, SquidのSSL Bumpを用いてHTTPS通信のリクエストパス等を可視化するもの

- 実用性はなく, 2025年7月の最新環境でSquid + SSL Bumpが動いた記録および検証用のリポジトリです

  - ルーティングやSquidの設定は「ひとまずこれで動いた」という一例と考えて下さい

- 元々はキャッシュ用プロキシサーバ検討時の副産物です. 下記の理由でキャッシュにはほとんど使えません

  - クライアント端末のOS/ブラウザ等にTLS証明書をインストールする必要がある
  - SquidがキャッシュできるWebコンテンツは限定的 (レスポンスヘッダにLast-Modifiedがある等)


<br>

### 動作した環境

- WAN側 : 有線

- LAN側 : 無線

- ここに図を入れる

- システム

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

- コンテナ

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

2. いわゆるオレオレ証明書を作成

   ```sh
   openssl req -new -newkey rsa:2048 -days <証明書の有効日数> -nodes -x509 \
     -subj '/C=JP' \
     -keyout ./conf/squid_bump.key \
     -out ./conf/squid_bump.crt
   ```

3. LAN側のNIC名を `ip a` 等で確認し `start.sh` に設定

   https://github.com/ec22s/docker-squid-sslbump/blob/070c3fe3ed99e357c57f518553b51e18625d2487/start.sh#L1-L2

4. 起動・終了

   ```sh
   sudo ./start.sh
   ```

   - 問題なければ最後に `docker ps -a` の出力が表示されます

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

### 動作検証した内容

- ホストPCの有線LANをインターネットに接続

- ホストPCの無線LANをホットスポットに設定 (インターネット接続を共有)

- いわゆるオレオレ証明書をホストPC上で作成し `conf` ディレクトリに保存

- 無線LANのNIC名を `start.sh` に設定

- コンテナ起動

- 他のPCに `conf/squid_bump.crt` をコピー, ホットスポットに接続してコマンド実行

  ```sh
  # HTTPサイトに初回アクセス
  curl curl http://abehiroshi.la.coocan.jp/

  # 同じHTTPサイトにもう一度アクセス (*1)
  curl curl http://abehiroshi.la.coocan.jp/

  # オレオレ証明書を利用してHTTPSサイトに初回アクセス
  curl --cacert squid_bump.crt https://www.saitama-u.ac.jp/entrance/

  # 同じHTTPSサイトにもう一度アクセス (*2)
  curl --cacert squid_bump.crt https://www.saitama-u.ac.jp/entrance/
  ```

- 上記に対するSquidのアクセスログ確認

  ```
  *1) ... TCP_MEM_HIT/200 855 GET http://abehiroshi.la.coocan.jp/ - HIER_NONE/- text/html
  *2) ... TCP_HIT/200 115349 GET https://www.saitama-u.ac.jp/entrance/ - HIER_NONE/- text/html
  ```

- HTTP・HTTPSともにキャッシュがあり, HTTPS通信のリクエストパスが復元されている

- ただし多くのWebサイトではSquidがキャッシュできない. レスポンスヘッダに `Last-Modified` がない等の理由で, リクエストの都度コンテンツを取得してしまう

<br>

以上
