-- ═══════════════════════════════════════════════════════════════════
-- 사운드팀 음원 견적 관리 (Music Quotes)
--   * 시스템팀 견적 관리(quotes 테이블)와 완전 분리된 별도 스키마
--   * Needle 견적서(OTT/광고/영화) + Annual 견적서 + 거래명세서 통합
--   * 처음엔 developer(임종완 주임) 계정 테스트 전용 → 이후 사운드팀 확대
-- 실행: Supabase Dashboard → SQL Editor → New query → 붙여넣고 Run
-- 무영향: 기존 quotes / journals / messages 등 전 테이블과 격리 (FK 없음)
-- ═══════════════════════════════════════════════════════════════════

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ music_quotes — 음원 견적서 · 거래명세서                    ┃
-- ┃  · doc_type: 'needle'(음원 사용 견적) | 'annual'(연간 블랭킷 라이선스) | 'invoice'(거래명세서)
-- ┃  · sub_type: 'ott' | 'ad' | 'movie' | NULL(annual/invoice 는 미사용)
-- ┃  · status:   '미결' | '진행' | '완료'
-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
CREATE TABLE IF NOT EXISTS music_quotes (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- 분류 · 관리용 (엑셀에는 안 나가는 내부 필드)
  doc_type             TEXT NOT NULL,               -- 'needle' | 'annual' | 'invoice'
  sub_type             TEXT,                        -- 'ott' | 'ad' | 'movie' | NULL
  quote_no             TEXT,                        -- 견적서 번호 (예: 2026-08-001)
  status               TEXT DEFAULT '미결',          -- '미결' | '진행' | '완료'
  tax_invoice_date     DATE,                        -- 세금계산서 발행일 (내부 관리용)
  -- 견적서 상단 좌측 (엑셀 출력에 나감)
  doc_date             DATE,                        -- DATE (견적서 일자)
  receiver_company     TEXT,                        -- 수신 (회사명)
  receiver_person      TEXT,                        -- 참조 (수신 담당자)
  receiver_tel         TEXT,                        -- 수신자 Tel
  receiver_fax         TEXT,                        -- 수신자 Fax
  doc_title            TEXT,                        -- 제목
  -- 견적서 상단 우측 - 발신자 정보 (미디어큐브 고정 기본값이지만 편집 가능)
  sender_reg_no        TEXT DEFAULT '114-86-09186', -- 등록번호
  sender_company       TEXT DEFAULT '(주)미디어큐브',
  sender_ceo           TEXT DEFAULT '김재경',
  sender_address       TEXT DEFAULT '서울 강남구 논현로136길16',
  sender_biz_type      TEXT DEFAULT '서비스',        -- 업태
  sender_biz_item      TEXT DEFAULT '음원제작·유통', -- 업종
  sender_tel           TEXT DEFAULT '02-534-8408',
  sender_fax           TEXT DEFAULT '02-534-8486',
  sender_person        TEXT DEFAULT '이광순',       -- 담당자
  -- 표 (items) - sub_type 마다 스키마 다름 → JSONB 로 유연 저장
  --   예 OTT:   [{no,cdTitle,cdNo,cue,trackNo,publisher,unit,qty,dwPrice}]
  --   예 광고: [{no,cdTitle,cdNo,cue,trackNo,publisher,unit,qty,amount}]
  --   예 영화: [{no,cdTitle,cdNo,cue,trackNo,publisher,unit,qty,domestic,worldwide}]
  --   예 Annual: [{no,item,code,spec,unit,qty,unitPrice,supplyPrice,vat,totalWithVat}]
  items                JSONB DEFAULT '[]'::jsonb,
  -- 첨부파일 (PDF/Excel 등)
  attachments          JSONB DEFAULT '[]'::jsonb,   -- [{name,url,size,type}]
  -- 메타
  author_id            TEXT,
  author_name          TEXT,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);

-- 인덱스 (자주 쓰는 정렬/필터)
CREATE INDEX IF NOT EXISTS idx_mq_created_at ON music_quotes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mq_doc_date   ON music_quotes(doc_date DESC);
CREATE INDEX IF NOT EXISTS idx_mq_doc_type   ON music_quotes(doc_type);
CREATE INDEX IF NOT EXISTS idx_mq_status     ON music_quotes(status);

-- RLS all-open (현 프로젝트 다른 테이블과 동일 정책)
ALTER TABLE music_quotes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "music_quotes_all" ON music_quotes;
CREATE POLICY "music_quotes_all" ON music_quotes
  FOR ALL USING (true) WITH CHECK (true);

-- 2026-10-30 자동노출 차단 정책 대응 — GRANT 명시 필수
GRANT SELECT, INSERT, UPDATE, DELETE ON music_quotes TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 롤백: DROP TABLE IF EXISTS music_quotes CASCADE;
-- ═══════════════════════════════════════════════════════════════════
