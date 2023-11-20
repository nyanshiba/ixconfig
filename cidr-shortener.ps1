#!/usr/bin/env pwsh
#requires -version 7

param
(
    [parameter(mandatory)]
    [string]$FilePath,
    [Int32]$subnetRoundFactor = 8
)

# [System.Net.IPAddress]::Parse('192.0.2.0').IPAddressToString は 0.2.0.192 である。異論しかない。
# [System.Net.IPAddress]::New()で初期化すると、表示だけが正しくなって動作は逆のままなので、お気を付けて
function Get-ReversedIPAddressString
{
    param
    (
        [string]$ipaddr
    )

    [System.Collections.Generic.List[string]]$split = $ipaddr.Split(".")
    $split.Reverse()
    return $split -join "."
}

function Get-IPAddressBytesFromCIDR
{
    param
    (
        [string]$ipAddressString,
        [Int32]$subnetBits
    )

    # IPアドレスのビット数からネットマスクに変換 /18 = 11111111 11111111 11000000 00000000
    $subnetMask = [System.Net.IPAddress]::Parse("255.255.255.255").Address -shr (32 - $subnetBits) -shl (32 - $subnetBits)

    # ネットマスクで正しい先頭アドレスを計算、ビット列に変換
    $IPAddressBytes = [System.Net.IPAddress]::Parse((Get-ReversedIPAddressString -ipaddr $ipAddressString)).Address -band $subnetMask

    # IPアドレスのビット数からネットマスクに変換 /18 = 00000000 00000000 00111111 11111111
    $subnetMask = [System.Net.IPAddress]::Parse("255.255.255.255").Address -shr $subnetBits

    # ブロードキャストアドレスは、IPアドレスとネットマスクのORに等しい
    $BroadcastBytes = $IPAddressBytes -bor $subnetMask

    return [PSCustomObject]@{
        ipAddressString = ([System.BitConverter]::GetBytes($IPAddressBytes)[3..0] -join '.')
        subnetBits = $subnetBits
        IPAddressBytes = $IPAddressBytes
        BroadcastBytes = $BroadcastBytes
    }
}

# スクリプトの引数に指定されたipsetを読む
[System.Collections.ArrayList]$ipset = Get-Content -LiteralPath $FilePath | ConvertFrom-Csv -Header ipAddressString, subnetBits, IPAddressBytes, BroadcastBytes -Delimiter "/"

# 差分がなくなるまで繰り返す
do
{
    $ipsetLength = $ipset.Count
    for ($i = 0; $i -lt $ipset.Count; $i++)
    {
        # 今のIP範囲のブロードキャストを取得
        if (!$ipset[$i].BroadcastBytes)
        {
            [void]$ipset.Insert(
                ($i),
                (Get-IPAddressBytesFromCIDR -ipAddressString $ipset[$i].ipAddressString -subnetBits $ipset[$i].subnetBits)
            )
            [void]$ipset.RemoveAt(($i+1))
        }

        # IP範囲が、一つ前のIP範囲内なら削除 (入力したipsetあるいは丸めたことにより)
        if ($i -ne 0 -And $ipset[$i].BroadcastBytes -le $ipset[($i-1)].BroadcastBytes)
        {
            Write-Host "DEBUG: Remove $($ipset[$i].ipAddressString)/$($ipset[$i].subnetBits) $($ipset[$i].BroadcastBytes)"
            [void]$ipset.RemoveAt($i)

            # 配列が減るのでデクリメント
            $i--
        }
        # 最後のIP範囲以外は丸めてみる
        elseif ($i -ne ($ipset.Count - 1))
        {
            # 比較用に次のIP範囲を取得
            if (!$ipset[$i+1].BroadcastBytes)
            {
                [void]$ipset.Insert(
                    ($i+1),
                    (Get-IPAddressBytesFromCIDR -ipAddressString $ipset[$i+1].ipAddressString -subnetBits $ipset[$i+1].subnetBits)
                )
                [void]$ipset.RemoveAt(($i+2))
            }

            # 広いIP範囲は増加しづらくする
            $subnetSubtract = [Math]::Max(1, [Int32]($subnetRoundFactor * ([Int32]$ipset[$i].subnetBits - 8) /16))
            # $subnetSubtract = [Math]::Max(1, [Int32]($subnetRoundFactor * [Int32]$ipset[$i].subnetBits / 24))
            
            # IP範囲を、引数で指定されたサブネットマスクの粗さまで拡大していく
            foreach ($s in 0..$subnetSubtract)
            {
                # ブロードキャストを再取得
                $Current = $s -eq 0 ? $ipset[$i] : (Get-IPAddressBytesFromCIDR -ipAddressString $ipset[$i].ipAddressString -subnetBits ([Int32]$ipset[$i].subnetBits - $s))

                # IP範囲が被った
                if ($ipset[$i+1].BroadcastBytes -le $Current.BroadcastBytes)
                {
                    # サブネットマスクが変わっていれば
                    if ($s -ne 0)
                    {
                        # 丸めたIP範囲をipsetに記す
                        [void]$ipset.Insert(
                            $i,
                            $Current
                        )
                        [void]$ipset.RemoveAt(($i+1))
                        Write-Host "DEBUG: Change $($ipset[$i].ipAddressString)/$($ipset[$i].subnetBits) $($ipset[$i].BroadcastBytes)"
                    }
                    break
                }
            }
        }
    }

    # IP範囲の先頭アドレスが小さい順、その中でサブネットマスクが小さい順で並べ替えて次のターンへ
    $ipset = $ipset | Sort-Object -Property subnetBits | Sort-Object -Property IPAddressBytes
} while ($ipsetLength -ne $ipset.Count)

# 標準出力にipset形式で書き出す
$ipset | Select-Object ipAddressString, subnetBits | ConvertTo-Csv -Delimiter '/' -UseQuotes Never | Select-Object -Skip 1
Write-Host ([string]$ipset.Count + " IP ranges.")
