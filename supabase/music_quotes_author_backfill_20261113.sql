-- ═══════════════════════════════════════════════════════════════════
-- 음원 견적 · 기존 견적서 작성자 지정 (2026-11-13)
--   * 수정·삭제 권한이 "작성자 본인 + 예외 계정" 기준으로 바뀌면서
--     기존 견적서 2건(2026-005, 2026-006)의 작성자를 이광순 이사(sunlee)로 지정
--   * 앱에서 sunlee 계정이 저장할 때와 같은 값: author_id='sunlee', author_name='이광순 이사'
--   * 변경 컬럼: author_id, author_name 두 개만 (updated_at·내용·다른 견적서는 그대로)
-- 실행: Supabase Dashboard → SQL Editor → New query → 붙여넣고 Run
-- ═══════════════════════════════════════════════════════════════════

-- ① 미리보기 (선택) — 바꾸기 전 현재 작성자 확인
SELECT quote_no, doc_type, doc_title, author_id, author_name, created_at
FROM music_quotes
WHERE quote_no IN ('2026-005', '2026-006')
  AND doc_type <> 'invoice'
ORDER BY quote_no;

-- ② 적용 — 결과에 2행이 나오면 정상
UPDATE music_quotes
SET author_id   = 'sunlee',
    author_name = '이광순 이사'
WHERE quote_no IN ('2026-005', '2026-006')
  AND doc_type <> 'invoice'
RETURNING quote_no, doc_title, author_id, author_name;

-- ═══════════════════════════════════════════════════════════════════
-- 되돌리기: ① 미리보기에서 확인한 원래 author_id / author_name 값으로 같은 UPDATE 실행
-- ═══════════════════════════════════════════════════════════════════
