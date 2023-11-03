#!/usr/bin/env pwsh
#requires -version 7

param
(
    [parameter(mandatory)]
    [string]$FilePath,
    [Int32]$subnetRoundFactor = 0
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
    return [System.Net.IPAddress]::Parse((Get-ReversedIPAddressString -ipaddr $ipAddressString)).Address -band $subnetMask
}

function Get-BroadcastAddressFromBytes
{
    param
    (
        [Int64]$ipAddressBytes,
        [Int32]$subnetBits
    )

    # IPアドレスのビット数からネットマスクに変換 /18 = 00000000 00000000 00111111 11111111
    $subnetMask = [System.Net.IPAddress]::Parse("255.255.255.255").Address -shr $subnetBits

    # ブロードキャストアドレスは、IPアドレスとネットマスクのORに等しい
    return $ipAddressBytes -bor $subnetMask
}

# スクリプトの引数に指定されたipsetを読んで、IP範囲ごとに処理
$cnt = 0
$lastBroadcastBytes = 0
$beforeCidrStringArray = "0.0.0.0", "32"
((Get-Content -LiteralPath $FilePath) -split "\r?\n") + @("255.255.255.255/32") | Foreach-Object {

    # IPアドレスとサブネットマスクを比較可能な形式で取得
    $cidrStringArray = $_.Split('/')
    $IPAddressBytes = Get-IPAddressBytesFromCIDR -ipAddressString $cidrStringArray[0] -subnetBits $cidrStringArray[1]
    
    # 広いIP範囲は増加しづらくする
    $subnetSubtract = [Math]::Max(0, [int32]($subnetRoundFactor * ([Int32]$beforeCidrStringArray[1] - 8) /16))
    # 一つ前のIP範囲を、引数で指定されたサブネットマスクの粗さまで拡大していく
    foreach ($i in 0..$subnetSubtract)
    {
        # 一つ前のブロードキャストを取得
        $beforeIPAddressBytes = Get-IPAddressBytesFromCIDR -ipAddressString $beforeCidrStringArray[0] -subnetBits ([Int32]$beforeCidrStringArray[1] - $i)
        $beforeBroadcastBytes = Get-BroadcastAddressFromBytes -ipAddressBytes $beforeIPAddressBytes -subnetBits ([Int32]$beforeCidrStringArray[1] - $i)
        # 一つ前のブロードキャストが、最後にipsetへ記したIP範囲内なら無視
        if ($beforeBroadcastBytes -le $lastBroadcastBytes)
        {
            break
        }

        # IP範囲は全く被っていない
        if ($IPAddressBytes -gt $beforeBroadcastBytes)
        {
            # Write-Host "かぶってない"
            # 丸めてよい最大のIP範囲でも被らないなら、ipsetに書かれた元のIP範囲を記す
            if ($i -eq $subnetSubtract)
            {
                # 丸める前のIP範囲をipsetに記す
                Write-Output ($beforeCidrStringArray -join '/')

                # 本当は違うけど、比較に使う以上被らないので再計算は不要
                $lastBroadcastBytes = $beforeBroadcastBytes

                $cnt++
                break
            }
        } else # 被った
        {
            # 丸めたIP範囲をipsetに記す
            Write-Output (([System.BitConverter]::GetBytes($beforeIPAddressBytes)[3..0] -join '.') + '/' + ([Int32]$beforeCidrStringArray[1] - $i))
            $lastBroadcastBytes = $beforeBroadcastBytes

            $cnt++
            break
        }
    }

    $beforeCidrStringArray = $cidrStringArray
}

Write-Host "$cnt IP ranges."
