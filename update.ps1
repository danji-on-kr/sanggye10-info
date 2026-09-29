# 단지온 주 2회(화·금) 갱신 도우미
#
#   powershell -ExecutionPolicy Bypass -File update.ps1
#
# 1) 게시판에 새 글이 있는지 확인한다.
# 2) 새 글이 없으면 아무것도 하지 않고 끝낸다.
# 3) 새 글이 있으면 목록을 보여주고 멈춘다. 내용 판단과 data.json 수정은 사람이(또는 Claude가) 한다.
#
# 자동으로 페이지 내용을 고치지 않는 이유:
#   공고 한 장이 쟁점을 통째로 뒤집는 일이 실제로 있었다(2026-08-12 계약해지 가결).
#   기계가 제목만 보고 요약하면 틀린 내용을 주민에게 보여주게 된다.

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot

Write-Host "=== 단지온 갱신 확인 ($(Get-Date -Format 'yyyy-MM-dd HH:mm')) ===" -ForegroundColor Cyan

python check_updates.py
$code = $LASTEXITCODE

switch ($code) {
    0 {
        Write-Host "`n할 일 없음. 종료합니다." -ForegroundColor Green
    }
    1 {
        Write-Host "`n--- 새 글이 있습니다 ---" -ForegroundColor Yellow
        Write-Host "다음 순서로 진행하세요:" -ForegroundColor Yellow
        Write-Host "  1. 위 목록에서 단지온에 실을 만한 글을 고른다"
        Write-Host "  2. 첨부 PDF는 아래처럼 직접 내려받아 읽는다 (브라우저 쓰지 말 것 — 상세페이지가 자주 멈춘다)"
        Write-Host '     Invoke-WebRequest "https://openapt.seoul.go.kr/open/FileDown.do?atchFileId=FILE_xxx&fileSn=0" -OutFile a.pdf'
        Write-Host "  3. data.json 의 timeline / openIssues 와 index.html 소식 카드를 고친다"
        Write-Host "  4. data.json 의 updatedAt 과 index.html 의 기준일을 오늘 날짜로 바꾼다"
        Write-Host "  5. .\update.ps1 -Publish 로 커밋·푸시한다"
    }
    default {
        Write-Host "`n확인 실패. 네트워크 문제이거나 사이트 구조가 바뀌었을 수 있습니다." -ForegroundColor Red
        Write-Host "check_updates.py 의 정규식을 점검하세요." -ForegroundColor Red
    }
}

exit $code
