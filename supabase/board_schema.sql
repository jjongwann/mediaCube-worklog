-- ═══════════════════════════════════════════════════════════
-- 사내 게시판 스키마
-- 실행 방법: Supabase Dashboard → SQL Editor → New query → 아래 붙여넣고 Run
-- 무영향: 기존 테이블(journals, task_directives, meeting_minutes 등)과 완전 분리
-- ═══════════════════════════════════════════════════════════

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ 1. board_posts — 게시글                                ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
CREATE TABLE IF NOT EXISTS board_posts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category       TEXT NOT NULL,             -- 'notice' | 'work' | 'file' | 'free' | 'suggest'
  title          TEXT NOT NULL,
  content        TEXT DEFAULT '',
  author_id      TEXT NOT NULL,
  author_name    TEXT,
  author_dept    TEXT,
  visibility     TEXT DEFAULT 'all',        -- 'all' | 'dept' | 'user'
  visibility_targets JSONB DEFAULT '[]'::jsonb,  -- dept 배열 or user_id 배열
  attachments    JSONB DEFAULT '[]'::jsonb, -- [{name,url,size,type}]
  allow_comments BOOLEAN DEFAULT TRUE,
  is_pinned      BOOLEAN DEFAULT FALSE,     -- 상단 고정 (관리자)
  is_important   BOOLEAN DEFAULT FALSE,     -- 중요 강조 (관리자)
  view_count     INT DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_board_posts_created_at ON board_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_board_posts_category   ON board_posts(category);
CREATE INDEX IF NOT EXISTS idx_board_posts_author_id  ON board_posts(author_id);

ALTER TABLE board_posts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "board_posts_all" ON board_posts;
CREATE POLICY "board_posts_all" ON board_posts FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON board_posts TO anon, authenticated;

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ 2. board_comments — 댓글 (대댓글 1단계 지원)          ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
CREATE TABLE IF NOT EXISTS board_comments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id           UUID NOT NULL REFERENCES board_posts(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES board_comments(id) ON DELETE CASCADE,
  author_id         TEXT NOT NULL,
  author_name       TEXT,
  content           TEXT NOT NULL,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_board_comments_post_id     ON board_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_board_comments_parent      ON board_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_board_comments_created_at  ON board_comments(created_at);

ALTER TABLE board_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "board_comments_all" ON board_comments;
CREATE POLICY "board_comments_all" ON board_comments FOR ALL USING (true) WITH CHECK (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON board_comments TO anon, authenticated;

-- ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
-- ┃ 3. 조회수 원자적 증가 RPC (중복 방지 → sessionStorage) ┃
-- ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
CREATE OR REPLACE FUNCTION board_increment_view(p_id UUID)
RETURNS INT LANGUAGE plpgsql AS $$
DECLARE new_count INT;
BEGIN
  UPDATE board_posts SET view_count = view_count + 1 WHERE id = p_id
  RETURNING view_count INTO new_count;
  RETURN new_count;
END; $$;

GRANT EXECUTE ON FUNCTION board_increment_view(UUID) TO anon, authenticated;
