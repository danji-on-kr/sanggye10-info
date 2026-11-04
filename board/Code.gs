/**
 * 단지온 주민 의견 게시판 백엔드 (Google Sheet 연결형 Apps Script)
 * 배포: 시트 → 확장 프로그램 → Apps Script에 붙여넣기 → setup() 1회 실행 →
 *       배포 > 새 배포 > 웹 앱 (실행: 나, 액세스: 모든 사용자) → /exec URL을 index.html 의 BOARD_URL 에 넣기
 * 운영: 시트 E열 '상태'만 바꾸면 사이트에 반영된다.
 *   대기(기본·비공개) / 검토중·반영됨·미반영(공개) / 삭제(비공개)   F열 '운영자 답변'은 공개된다.
 */
const SHEET = '의견';
const PUBLIC = ['검토중', '반영됨', '미반영'];
const CATS = ['관리비', '거버넌스', '시설·수선', '이 페이지 개선', '기타'];

function sheet_() {
  return SpreadsheetApp.getActive().getSheetByName(SHEET);
}

function setup() {
  const ss = SpreadsheetApp.getActive();
  const sh = ss.getSheetByName(SHEET) || ss.insertSheet(SHEET);
  sh.getRange(1, 1, 1, 7).setValues([['시각', '분류', '닉네임', '내용', '상태', '운영자 답변', 'id']]).setFontWeight('bold');
  sh.getRange('E2:E1000').setDataValidation(
    SpreadsheetApp.newDataValidation().requireValueInList(['대기'].concat(PUBLIC, ['삭제']), true).build());
  sh.setFrozenRows(1);
}

function doGet() {
  const rows = sheet_().getDataRange().getValues().slice(1);
  const items = rows
    .filter(r => PUBLIC.indexOf(r[4]) >= 0)
    .map(r => ({ id: r[6], t: Utilities.formatDate(new Date(r[0]), 'Asia/Seoul', 'yyyy-MM-dd'),
                 cat: r[1], nick: r[2], body: r[3], status: r[4], reply: r[5] }))
    .reverse().slice(0, 100);
  return ContentService.createTextOutput(JSON.stringify({ items: items })).setMimeType(ContentService.MimeType.JSON);
}

function clean_(v, n) {
  v = String(v || '').replace(/[\u0000-\u0008\u000B-\u001F]/g, '').trim().slice(0, n);
  return /^[=+\-@]/.test(v) ? "'" + v : v; // 수식 주입 방지
}

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(10000);
  try {
    const d = JSON.parse(e.postData.contents);
    if (d.hp) return ok_();                                   // 봇(허니팟)
    const body = clean_(d.body, 300);
    if (body.length < 5) return ok_();
    const cache = CacheService.getScriptCache();
    const key = 'n' + Math.floor(Date.now() / 60000);          // 분당 20건 제한
    const n = +(cache.get(key) || 0);
    if (n >= 20) return ok_();
    cache.put(key, String(n + 1), 120);
    const cat = CATS.indexOf(d.cat) >= 0 ? d.cat : '기타';
    const nick = clean_(d.nick, 12) || '익명 주민';
    sheet_().appendRow([new Date(), cat, nick, body, '대기', '', Utilities.getUuid().slice(0, 8)]);
    try { MailApp.sendEmail(Session.getEffectiveUser().getEmail(), '[단지온] 새 의견', cat + ' · ' + nick + '\n\n' + body); } catch (x) {}
    return ok_();
  } finally {
    lock.releaseLock();
  }
}

function ok_() {
  return ContentService.createTextOutput('{"ok":true}').setMimeType(ContentService.MimeType.JSON);
}
