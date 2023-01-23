# オペレーションモードからグローバルコンフィグモードへの移行
echo 'exit' > /dev/ttyS3
sleep 5
echo 'configure' > /dev/ttyS3
echo 'terminal length 0' > /dev/ttyS3
sleep 5

# 10秒間COM3をファイルに書き出す
# nohup sh -c 'timeout 60 cat -e /dev/ttyS3' > running-config.cfg &
nohup sh -c 'timeout 60 cat /dev/ttyS3' | tr -d '\r' > running-config.cfg 2>&1 &
sleep 5

# 現在の設定情報を表示するコマンドを送信
echo 'show running-config' > /dev/ttyS3
