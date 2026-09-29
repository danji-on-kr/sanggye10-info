# 단지온 자동 점검 (윈도우 작업 스케줄러용 · 화·금 실행)
#
# 등록:
#   schtasks /Create /TN "danji-on 주2회 점검" /SC WEEKLY /D TUE,FRI /ST 10:17 ^
#     /TR "powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\Eric\danji-on\scheduled_check.ps1"
#
# 하는 일:
#   1. 게시판에 새 글이 있는지 확인한다.
#   2. 결과를 _check_log.txt 에 한 줄 남긴다.
#   3. 새 글이 있으면 바탕화면에 '단지온_새글있음.txt' 를 만들어 눈에 띄게 한다.
#
# 내용 판단과 페이지 수정은 하지 않는다. 사람이(또는 Claude가) 원문을 보고 결정한다.
# 공고 한 장이 쟁점을 뒤집은 전례가 있어(2026-08-12 계약해지 가결) 제목만으로 요약하면 위험하다.

$ErrorActionPreference = 'Continue'
Set-Location -LiteralPath $PSScriptRoot

$stamp   = Get-Date -Format 'yyyy-MM-dd HH:mm'
$logPath = Join-Path $PSScriptRoot '_check_log.txt'
$marker  = Join-Path ([Environment]::GetFolderPath('Desktop')) '단지온_새글있음.txt'

$output = & python check_updates.py 2>&1
$code   = $LASTEXITCODE

switch ($code) {
    0 {
        Add-Content -LiteralPath $logPath -Value "[$stamp] 새 글 없음" -Encoding UTF8
    }
    1 {
        Add-Content -LiteralPath $logPath -Value "[$stamp] 새 글 발견" -Encoding UTF8
        $output | ForEach-Object { Add-Content -LiteralPath $logPath -Value "    $_" -Encoding UTF8 }

        $body = @()
        $body += "단지온 · 새 글이 올라왔습니다 ($stamp)"
        $body += ""
        $body += $output
        $body += ""
        $body += "다음: 클로드에게 '단지온 확인해줘' 라고 하시면 원문을 읽고 페이지에 반영합니다."
        $body += "확인이 끝나면 이 파일은 지우셔도 됩니다."
        Set-Content -LiteralPath $marker -Value ($body -join "`r`n") -Encoding UTF8
    }
    default {
        Add-Content -LiteralPath $logPath -Value "[$stamp] 확인 실패 (exit=$code)" -Encoding UTF8
        $output | ForEach-Object { Add-Content -LiteralPath $logPath -Value "    $_" -Encoding UTF8 }
    }
}

exit $code
