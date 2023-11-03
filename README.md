# ixconfig
UNIVERGE IXの設定関連ツール置き場

## cidr-shortener.ps1

[ipv4.fetus.jp: 国/地域別IPアドレス(IPv4アドレス)割り振り（割り当て）一覧](https://ipv4.fetus.jp/) のようなCIDR表記のipsetから、IP範囲を纏めた大雑把なACLを生成したいときに

```powershell
# 同じsubnetRoundFactorで繰り返してから大きくするとよい
./cidr-shortener.ps1 -FilePath /tmp/code-stdin-dni -subnetRoundFactor 4 | code -
```

## dns-host-helper.sh

[ルータでDNSシンクホール、例えばRTXでdns static](https://nyanshiba.com/blog/yamahartx-settings/#dns%E3%82%B7%E3%83%B3%E3%82%AF%E3%83%9B%E3%83%BC%E3%83%AB) するように、AAAA/Aレコードを確認して`dns host`コマンドをシリアルコンソール`'dev/ttyS3`へ入力する  

```sh
./dns-host-helper.sh example.co.jp crypto.cloudflare.com
./dns-host-helper.sh -n example.co.jp crypto.cloudflare.com
```

[AppleデバイスやChromium系ブラウザがクエリするHTTPS RRは、OpenDNSやCloudflare Zero Trust](https://nyanshiba.com/blog/yamahartx-settings/#ios-14macos-11%E5%AF%BE%E5%BF%9C)を`proxy-dns server`に設定することで対応可能

## get-running-config.sh

シリアルコンソールからconfigを取得する
```sh
./get-running-config.sh
# running-config.cfg
```
