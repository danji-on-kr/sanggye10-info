"""단지온 - 서울시 통합정보마당 새 게시물 감지기

주 2회(화·금) 실행해서 상계주공10단지 게시판에 새 글이 올라왔는지만 확인한다.
새 글이 있으면 목록을 출력하고 종료코드 1, 없으면 0.

  python check_updates.py

브라우저를 쓰지 않는다. 상세페이지는 렌더러가 자주 얼어서 자동화에 부적합하고,
목록 페이지는 서버가 HTML로 그대로 내려주므로 HTTP 요청만으로 충분하다.

첨부파일은 로그인 없이 받을 수 있다:
  https://openapt.seoul.go.kr/open/FileDown.do?atchFileId=FILE_xxx&fileSn=0
"""
import json
import re
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

APT_CODE = "A13920804"
INDEX_URL = f"https://openapt.seoul.go.kr/openApt/index.do?aptCode={APT_CODE}"
SNAPSHOT = Path(__file__).with_name("_snapshot.json")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0 Safari/537.36"

# 목록 페이지의 글 링크는 goActDetail('게시판', 글번호) 형태다.
POST_RE = re.compile(r"goActDetail\('([A-Za-z]+)',\s*(\d+)\)")
# 링크 바로 뒤에 제목이 붙는다. 태그를 걷어내고 쓴다.
TITLE_RE = re.compile(r"goActDetail\('[A-Za-z]+',\s*\d+\)[^>]*>(.*?)</a>", re.S)
TAG_RE = re.compile(r"<[^>]+>")


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "replace")


def parse_posts(html: str) -> dict:
    """{'게시판/글번호': '제목'} 형태로 모은다."""
    ids = POST_RE.findall(html)
    titles = [TAG_RE.sub("", t).strip() for t in TITLE_RE.findall(html)]
    posts = {}
    for (board, num), title in zip(ids, titles):
        if title:
            posts[f"{board}/{num}"] = title
    return posts


def load_snapshot() -> dict:
    if not SNAPSHOT.exists():
        return {}
    try:
        return json.loads(SNAPSHOT.read_text(encoding="utf-8")).get("posts", {})
    except (json.JSONDecodeError, OSError):
        return {}


def save_snapshot(posts: dict) -> None:
    SNAPSHOT.write_text(
        json.dumps(
            {"checkedAt": datetime.now().strftime("%Y-%m-%d %H:%M"), "posts": posts},
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> int:
    try:
        posts = parse_posts(fetch(INDEX_URL))
    except Exception as e:  # 네트워크·사이트 장애는 실패로 끝내되 스냅샷은 건드리지 않는다
        print(f"확인 실패: {e}")
        return 2

    if not posts:
        print("확인 실패: 목록에서 글을 하나도 찾지 못했습니다. 사이트 구조가 바뀌었을 수 있습니다.")
        return 2

    old = load_snapshot()
    new = {k: v for k, v in posts.items() if k not in old}

    print(f"[{datetime.now():%Y-%m-%d %H:%M}] 게시물 {len(posts)}건 확인")

    if not old:
        save_snapshot(posts)
        print("첫 실행이라 현재 목록을 기준으로 저장했습니다. 다음 실행부터 새 글을 알려드립니다.")
        return 0

    if not new:
        save_snapshot(posts)
        print("새 글 없음.")
        return 0

    print(f"\n새 글 {len(new)}건:")
    for key, title in new.items():
        board, num = key.split("/")
        print(f"  - [{board}] {title}")
        print(f"    상세: 단지홈에서 goActDetail('{board}', {num})")
    save_snapshot(posts)
    return 1


if __name__ == "__main__":
    sys.exit(main())
