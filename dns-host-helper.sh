#!/bin/bash
server='1.1.1.1'
com='/dev/ttyS3'

function usage {
    cat <<EOF
$(basename ${0}) is a helper script for setting up a DNS sinkhole using the NEC IX router's "dns host" command.

Note: If there are Apple devices on the LAN that query CNAME again, then in addition to "dns host", "proxy-dns server" must also be configured to ignore Type65 RR queries.

Usage:
    $(basename ${0}) [<options>] [fqdn]

Example:
    $(basename ${0}) example.co.jp crypto.cloudflare.com
    $(basename ${0}) -n example.co.jp crypto.cloudflare.com

Options:
    --help, -h        print this
    -n                no dns host 
EOF
}

# オプション
while getopts hn opt;
do
    case $opt in
        h | help ) usage
            exit ;;
        n) no='no'
            shift $(($OPTIND - 1)) ;;
    esac
done

# シェルスクリプトに渡された引数$1...を順次処理
for fqdn;
do
    # Aレコードは常にあるものとみなす
    echo $no dns host $fqdn ip 0.0.0.0 > $com

    # AAAAレコードがあるか、eTLD+1でなければAAAAも改ざん
    aaaa=`dig +answer +noauthority +noclass +nocmd +nocomments +nocrypto +noquestion +norrcomments +nostats +nottlid aaaa @$server $fqdn`
    IFS=$'\n'
    aaaaary=(`echo "$aaaa"`)
    unset IFS
    echo "${aaaaary[0]}"
    if [ -n "$aaaa" ]; then
        echo $no dns host $fqdn ip :: > $com
    fi
done

# DNSキャッシュエントリ消去
echo 'clear dns cache' > $com
ipconfig.exe /flushdns
