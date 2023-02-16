# オペレーションモードからグローバルコンフィグモードへの移行
echo 'configure' > /dev/ttyS3
echo 'terminal length 0' > /dev/ttyS3
echo 'event-terminal stop' > /dev/ttyS3
sleep 3

# 10秒間COM3をファイルに書き出す
nohup sh -c 'timeout 300 cat /dev/ttyS3' | tr -s '\r\n' > running-config.cfg 2>&1 &
echo 'listening...'
sleep 5

# 現在の設定情報を表示するコマンドを送信
echo 'show running-config' > /dev/ttyS3
sleep 300
