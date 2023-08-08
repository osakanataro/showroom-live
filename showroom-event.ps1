#!/usr/bin/pwsh
param(
    [string]$eventurl="https://www.showroom-live.com/event/vgarden_audition2",
    [string]$outdir="~/Videos",
    [string]$streamlinkcmd="streamlink",
    [string]$quality="worst",
    [string]$lockfileext="showroomlockfile",
    [int32]$wait=300
)

$PSDefaultParameterValues['*:Encoding'] = 'utf8'

#$eventurl="https://www.showroom-live.com/event/beginner_official_vol67"

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

### 画質設定
#$quality="worst"                # 低画質
#$quality="best"                 # 高画質
#$quality="360p,144p,worst"      # 低めの画質で撮る
#このほか、配信者の送信設定により144p,360p,720p.1080pなどの画質設定がある


### ループ
$loop=0
$count=0
while ($loop -eq 0){
    # ロックファイル検出用にスクリプト開始時刻を取得
    $scriptstartdate = Get-Date
    
    ### 現在配信中のROOM検出
    $response=Invoke-WebRequest $eventurl
    
    # イベント名取得
    $tmpst=($response.Content).IndexOf("`"tx-title");
    $tmpst=($response.Content).IndexOf(">",$tmpst)+(">").Length
    $tmped=($response.Content).IndexOf("<",$tmpst)
    $eventtitle=($response.Content).Substring($tmpst,$tmped-$tmpst)
    # 進捗表示1
    if($count -eq 0){
        Write-Host $eventtitle
    }
    
    # 配信中のリンクには  class="ga-onlive-click" が含まれる
    $flag=0
    $twittercount=0
    $tmpst=0
    $tmped=0
    $nextst=0
    while ($flag -eq 0){
        $tmpst=($response.Content).IndexOf("ga-onlive-click",$nextst)
        if($tmpst -lt 1){
            $flag=1
        }else{
            $tmpst=($response.Content).IndexOf("href=",$tmpst)+("href=`"").Length
            $tmped=($response.Content).IndexOf("`"",$tmpst)
            $nextst=$tmped
            $onliveurl=($response.Content).Substring($tmpst,$tmped-$tmpst)
            #Write-Host $onliveurl
            $tmpst=($response.Content).LastIndexOf("onlivecard-name",$tmpst)+("onlivecard-name`">").Length
            $tmped=($response.Content).IndexOf("<",$tmpst)
            $onlivetitle=($response.Content).Substring($tmpst,$tmped-$tmpst)
            #Write-Host $onlivetitle
            $tmpst=($response.Content).LastIndexOf("is-onlive",$tmpst)
            $tmpst=($response.Content).IndexOf(">",$tmpst)+(">").Length
            $tmped=($response.Content).IndexOf("<",$tmpst)
            $onlivetime=($response.Content).Substring($tmpst,$tmped-$tmpst)
            #Write-Host $onlivetime

            $tmp=$onliveurl -replace "/r/",""
            $lockfile=$outdir+"/"+$tmp+"."+$lockfileext
            $datestr=Get-Date -Format "yyyyMMdd-HHmm"
            $outputfile=$outdir+"/"+$tmp+"-"+$datestr+".mp4"

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
                Start-Process $onliveurl
                # 配信開始したらstreamlinkで保存を開始
                #Start-Process -FilePath "streamlink" -ArgumentList $onliveurl,$quality,"--output",$outputfile
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
