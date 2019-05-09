#!/usr/bin/pwsh
param(
    [string]$roomurl="https://www.showroom-live.com/ringo-005",
    #[string]$streamlinkrecorddirectory="~/Videos",
    [string]$outdir="~/Videos",
    [string]$streamlinkcmd="streamlink",
    [string]$quolity="best",
    [switch]$record,
    [switch]$output,
    [int32]$wait=10
)

### CLI操作整備時に「streamlinkrecorddirectory」だと長すぎたのでoutdirで短縮
$streamlinkrecorddirectory=$outdir

### URLのサンプル
#$roomurl="https://www.showroom-live.com/ringo-005"   # 九条林檎
#$roomurl="https://www.showroom-live.com/lychee_9jo"  # 九条茘枝
#$roomurl="https://www.showroom-live.com/anzu_9jo"    # 九条杏子
#$roomurl="https://www.showroom-live.com/natsume_9jo" # 九条棗
#$roomurl="https://www.showroom-live.com/Fuka_Sibuki" # 紫吹 ふうか
#$roomurl="https://www.showroom-live.com/kuromi-003"  # 白乃クロミ
#$roomurl="https://www.showroom-live.com/ganbaruuko"  # がんばるぅ子
#$roomurl="https://www.showroom-live.com/monao_227"   # 青咲ローズ
#$streamlinkcmd="~/.local/bin/streamlink"

### Windows用設定
if([Environment]::OSVersion.Platform -eq "Win32NT"){
    $streamlinkcmd="C:\Program Files (x86)\Streamlink\bin\streamlink.exe"
    if($streamlinkrecorddirectory.IndexOf("/") -ne -1){
        $streamlinkrecorddirectory=[Environment]::GetFolderPath("MyVideo")
    }
}

### 画質設定
#$quolity="worst"                # 低画質
#$quolity="best"                 # 高画質
#このほか、配信者の送信設定により144p,360p,720p.1080pなどの画質設定がある
#また、後述するが設定によりFlashVideoデータとMPEG-TSデータが取得出来る

### streamlinkのオプション
$streamlinkoption=""            # 録音無し
if($output){
    $streamlinkoption="--output"    # ファイル録音
}
if($record){
    $streamlinkoption="--record"    # ファイル録音しつつVLCで再生
}

### roomid確認のためコンテンツ取得
$response=Invoke-WebRequest $roomurl
# 当初は ParsedHtml で実装したがWindows環境のみ対応なのでContentを検索する手法に変更
#$roomidtmp=$response.ParsedHtml.getElementsByName("twitter:app:url:googleplay") | Select-Object -ExpandProperty content
#$roomid=$roomidtmp.Substring($roomidtmp.IndexOf("=")+1)
$tmpst=($response.Content).IndexOf("twitter:app:url:googleplay")
$tmpst=($response.Content).IndexOf("room_id=",$tmpst)+("room_id=").Length
$tmped=($response.Content).IndexOf("`"",$tmpst)
$roomid=($response.Content).Substring($tmpst,$tmped-$tmpst)

### roomtitle取得
$tmpst=($response.Content).IndexOf("og:title")
$tmpst=($response.Content).IndexOf("content=`"",$tmpst)+("content=`"").Length
$tmped=($response.Content).IndexOf("`"",$tmpst)
$livetitle=($response.Content).Substring($tmpst,$tmped-$tmpst)
Write-Host $livetitle

### Windowタイトルにroomtitleを表示
if([Environment]::OSVersion.Platform -eq "Win32NT"){
    $Host.ui.RawUI.WindowTitle="showroom-live:"+$livetitle
}

$onlivecheckurl="https://www.showroom-live.com/room/is_live?room_id="+$roomid
$liveurl="https://www.showroom-live.com/room/get_live_data?room_id="+$roomid

### 配信開始チェック。未配信の場合は待機
# JSON形式で「ok」が「1」なら配信中。「0」だと未配信
$flag=0
$count=0
while ($flag -eq 0){
    $responsejson=Invoke-RestMethod $onlivecheckurl
    if( ($responsejson | Select-Object -ExpandProperty ok) -ne 1){
        Write-Host "." -NoNewline
        Start-Sleep -Seconds $wait
    }else{
        $flag=1
    }
    # 2時間毎に改行し、コンソールにタイトル表示もしておく
    if( $count -gt (3600 * 2 / $wait )){
    	Write-Host ""
	Write-Host $livetitle
	$count=0
    }
    $count++
}
Write-Host ""

### 最新のデータから配信のm3u8ファイルを検出するためにコンテンツ再取得
#当初、roomurlをパースしてm3u8ファイルを取得していたが、試しにstreamlinkに
#もとのURLを直接与えたら動いたが、FlashVideo形式とMPEG-TS(HLS)形式のどちらがworst/bestに割り当てられるかは
#配信設定に左右されてしまうようだ
#$response=Invoke-WebRequest $roomurl
#$tmped=($response.Content).IndexOf(".m3u8")+5
#$tmpst=($response.Content).LastIndexOf("https://",$tmped)
#$liveurl=($response.Content).Substring($tmpst,$tmped-$tmpst)
#$streamtypes=""

# streamlinkに「--stream-types hls」を指定すると、HLS形式で取得できる
# このオプションを指定しない場合、FlashVideo形式で取得される可能性がある
$streamtypes="--stream-types=hls"
$liveurl=$roomurl

### ファイル名決定
# ParsedHtml はWindows環境のみ対応なのでContentを検索する手法に変更
#$filetitle=$response.ParsedHtml.getElementsByTagName("title")|Select-Object -ExpandProperty text
#$tmpst=($response.Content).IndexOf("og:title")
#$tmpst=($response.Content).IndexOf("content=`"",$tmpst)+("content=`"").Length
#$tmped=($response.Content).IndexOf("`"",$tmpst)
#$livetitle=($response.Content).Substring($tmpst,$tmped-$tmpst)
#しかし、実行してみると、ルーム名はファイル名に使えない文字がよく使われ、除外が面倒なのでIDとする

### 保存用ファイル名に配信日時を入れる処理
# 面倒なのでFlashVideoで取得した場合であっても拡張子.mpg
# なお、FlashVideoの拡張子は.flv
$datestr=Get-Date -Format "yyyyMMdd-HHmm"
if([Environment]::OSVersion.Platform -eq "Win32NT"){
    $streamlinkfilename=$streamlinkrecorddirectory+"\"+$roomid+"_"+$datestr+"_"+$quolity+".mpg"
}else{
    $streamlinkfilename=$streamlinkrecorddirectory+"/"+$roomid+"_"+$datestr+"_"+$quolity+".mpg"
}

### streamlink コマンド実行
# Windowsの場合、Start-process だとコンソール出力の結果を同じ窓に出力することができなかったため、cmdで実行
if ($streamlinkoption -eq ""){
    if([Environment]::OSVersion.Platform -eq "Win32NT"){
        cmd /c $streamlinkcmd $streamtypes $liveurl $quolity
    }else{
        Start-Process -FilePath $streamlinkcmd -ArgumentList $streamtypes,$liveurl,$quolity -Wait -PassThru -NoNewWindow
    }
}else{
    if([Environment]::OSVersion.Platform -eq "Win32NT"){
        cmd /c $streamlinkcmd $streamtypes $liveurl $quolity $streamlinkoption $streamlinkfilename
    }else{
        Start-Process -FilePath $streamlinkcmd -ArgumentList $streamtypes,$liveurl,$quolity,$streamlinkoption,$streamlinkfilename -Wait -PassThru -NoNewWindow
    }
}
