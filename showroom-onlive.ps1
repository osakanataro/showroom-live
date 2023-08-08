#!/usr/bin/pwsh
param(
    [string]$outdir="~/Videos",
    [string]$streamlinkcmd="streamlink",
    [string]$quality="worst",
    [string]$lockfileext="showroomlockfile",
    [int32]$wait=300
)

#$wait=60
#$outdir="/showroom/vgardenall"

$onlivecheckurl="https://www.showroom-live.com/api/live/onlives"

# 調査対象のルーム
$checkrooms=@(
    'ringo-005'     # 林檎
    'lychee_9jo'    # 茘枝
    'natsume_9jo'   # 棗
    'eko-012'       # らみょん
    'vgarden_'      # vgarden
)


if([Environment]::OSVersion.Platform -eq "Win32NT"){
    if($outdir.IndexOf("/") -ne -1){
        $outdir=[Environment]::GetFolderPath("MyVideo")
    }
    # Windowsでstreamlink連携が上手くいかない場合に↓を使用
    #$streamlinkcmd="C:\Program Files (x86)\Streamlink\bin\streamlink.exe"
}

if ( !(Test-Path -Path $outdir)){
    Write-Host "Not found path: $outdir"
    exit
}

### ループ
$loop=0
$count=0
while ($loop -eq 0){
    # ロックファイル検出用にスクリプト開始時刻を取得
    $scriptstartdate = Get-Date

    # 進捗表示1
    if($count -eq 0){
        Write-Host "showroom配信検出スクリプト"
    }

    #
    $flag=0
    $twittercount=0

    # オンライブ一覧取得
    $response=Invoke-RestMethod -uri $onlivecheckurl

    #($response.onlives|where {$_.genre_id -eq $searchgenre}).lives
    #($response.onlives|where {$_.genre_id -eq $searchgenre}).lives | where {($_.room_url_key).indexof("vgarden_") -eq 0}

    ($response.onlives|where {$_.genre_id -eq $searchgenre}).lives | where {
        $roominfo=$_
        $checkrooms | ForEach-Object{
            $checkroom=$_
            if($roominfo.room_url_key.IndexOf($checkroom) -eq 0){
                $onlivetitle=$roominfo.main_name
                $onliveurl=$roominfo.room_url_key
                $onlivetime=$roominfo.started_at
                $lockfile=$outdir+"/"+$onliveurl+"."+$lockfileext
                $datestr=Get-Date -Format "yyyyMMdd-HHmm"
                $outputfile=$outdir+"/"+$onliveurl+"-"+$datestr+".mp4"
                #Write-Host "$onlivetitle $onliveurl $onlivetime"
                # 配信開始と新枠チェック
                $execflag=0
                if(!(Test-Path $lockfile)){
                    # 配信開始検出とロックファイル作成
                    $newfile=New-Item -ItemType File $lockfile
                    $tmpout=Add-Content -PassThru $lockfile -Value "$onlivetitle $onlivetime" -Encoding UTF8
                    $onliveurl="https://www.showroom-live.com"+$onliveurl
                    Write-Host "*** 配信開始検出 $onlivetitle $onliveurl 開始時刻 $onlivetime"
                    $execflag=1
                }else{
                    # 枠更新があったか確認
                    $filecontent=Get-Content -Path $lockfile
                    if($filecontent -eq "$onlivetitle $onlivetime"){
                        # 枠同じなのでロックファイル更新
                        $newfile=New-Item -ItemType File -force $lockfile
                        $tmpout=Add-Content -PassThru $lockfile -Value "$onlivetitle $onlivetime" -Encoding UTF8
                        #Write-Host "same:$onlivetitle $onlivetime"
                    }else{
                        # 新しい枠になってる場合はコマンドを実行
                        #Write-Host "new:$onlivetitle $onlivetime"
                        $execflag=1
                    }
                }
                # コマンド実行部分
                if($execflag -eq 1){
                    # twitter 発言
                    $twittercount=$twittercount+3
                    Write-Host $twittercount,$onlivetitle,"さんが配信しています",$onliveurl
                    #Start-Process -FilePath "./vgarden-twitter-send.py" -ArgumentList $twittercount,$onlivetitle,"さんが配信しています",$onliveurl
                    # 配信開始したらブラウザを開く
                    #Start-Process $onliveurl
                    # 配信開始したらstreamlinkで保存を開始
                    #Start-Process -FilePath "streamlink" -ArgumentList $onliveurl,$quality,"--output",$outputfile
                }
            }
        }
    }
    # 最近更新されていないロックファイル削除
    Get-ChildItem "$outdir/*.$lockfileext" | ForEach-Object {
        $fileitem=$_
        if($fileitem.LastWriteTime -lt $scriptstartdate){
            Write-Host "*** 配信終了 " -NoNewline
            Get-Content -Path $fileitem
            #Write-Host "$fileitem は配信終了済"
            Remove-Item -Path $fileitem
        }
    }

    # 進捗表示2
    Write-Host "." -NoNewline
    $count++
    if($count -gt 24 ){
        Write-Host ""
        $count=0
    }
    Start-Sleep $wait
}
