#!/usr/bin/pwsh
param(
    [string]$eventurl="https://www.showroom-live.com/event/vgarden_audition2",
    [string]$outdir="~/Videos",
    [string]$streamlinkcmd="streamlink",
    [string]$quality="worst",
    [string]$lockfileext="showroomlockfile",
    [int32]$wait=300
)

#$eventurl="https://www.showroom-live.com/event/beginner_official_vol67"

if ( !(Test-Path -Path $outdir)){
    Write-Host "Not found path: $outdir"
    exit
}

if([Environment]::OSVersion.Platform -eq "Win32NT"){
    if($outdir.IndexOf("/") -ne -1){
        $outdir=[Environment]::GetFolderPath("MyVideo")
    }
    # Windowsでstreamlink連携が上手くいかない場合に↓を使用
    #$streamlinkcmd="C:\Program Files (x86)\Streamlink\bin\streamlink.exe"
}

### 画質設定
#$quality="worst"                # 低画質
#$quality="best"                 # 高画質
#$quality="360p,144p,worst"      # 低めの画質で撮る
#このほか、配信者の送信設定により144p,360p,720p.1080pなどの画質設定がある


### ループ
$loop=0
while ($loop -eq 0){
    # ロックファイル検出用にスクリプト開始時刻を取得
    $scriptstartdate = Get-Date
    
    ### 現在配信中のROOM検出
    $response=Invoke-WebRequest $eventurl

    # 配信中のリンクには  class="ga-onlive-click" が含まれる
    $flag=0
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

            Write-Host "$onlivetitle $onliveurl $onlivetime"
            if(!(Test-Path $lockfile)){
                # 配信開始検出とロックファイル作成
                $newfile=New-Item -ItemType File $lockfile
                $onliveurl="https://www.showroom-live.com"+$onliveurl
                Write-Host "*** 配信開始検出 $onlivetitle URL:$onliveurl 開始時刻:$onlivetime"
                # 配信開始したらブラウザを開く
                Start-Process $onliveurl
                # 配信開始したらstreamlinkで保存を開始
                #Start-Process -FilePath "streamlink" -ArgumentList $onliveurl,$quality,"--output",$outputfile
            }else{
                # ロックファイル更新
                $newfile=New-Item -ItemType File -force $lockfile
            }
        }
    }

    # 最近更新されていないロックファイル削除
    Get-ChildItem "$outdir/*.$lockfileext" | ForEach-Object {
        $fileitem=$_
        if($fileitem.LastWriteTime -lt $scriptstartdate){
            Write-Host "$fileitem は配信終了済"
            Remove-Item -Path $fileitem
        }
    }

    Start-Sleep $wait
}
