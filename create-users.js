// 미디어큐브 계정 생성 스크립트 (Node.js)
// 실행: node create-users.js <service_role_key>
//
// service_role_key: Supabase 대시보드 → Settings → API Keys → Secret keys → default

const SB_URL = 'https://qkvatxowpkespdkxuoom.supabase.co';

const ACCOUNTS = [
  { username: 'info',         email: 'info@mediacube.com',         password: 'media6134' },
  { username: 'soundsupport', email: 'soundsupport@mediacube.com', password: 'media9912' },
  { username: 'webmaster20',  email: 'webmaster20@mediacube.com',  password: 'media2953' },
  { username: 'soundstore',   email: 'soundstore@mediacube.com',   password: 'media3042' },
  { username: 'soundsales',   email: 'soundsales@mediacube.com',   password: 'media1285' },
  { username: 'developer',    email: 'developer@mediacube.com',    password: 'mediacube8408' },
];

async function createUser(svcKey, account) {
  const res = await fetch(`${SB_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'apikey': svcKey,
      'Authorization': `Bearer ${svcKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: account.email,
      password: account.password,
      email_confirm: true,
      user_metadata: { username: account.username },
    }),
  });
  return res.json();
}

async function getAdminId(svcKey) {
  const res = await fetch(`${SB_URL}/auth/v1/admin/users?email=mediacube%40mediacube.com`, {
    headers: { 'apikey': svcKey, 'Authorization': `Bearer ${svcKey}` },
  });
  const data = await res.json();
  return (data.users && data.users.length > 0) ? data.users[0].id : null;
}

async function main() {
  const svcKey = process.argv[2];
  if (!svcKey) {
    console.error('사용법: node create-users.js <service_role_key>');
    process.exit(1);
  }

  console.log('[INFO] 계정 생성 시작...\n');

  for (const acc of ACCOUNTS) {
    process.stdout.write(`[...] ${acc.username} (${acc.email}) 생성 중... `);
    try {
      const result = await createUser(svcKey, acc);
      if (result.id) {
        console.log(`완료 (id: ${result.id})`);
      } else if (result.msg && result.msg.includes('already')) {
        console.log('이미 존재하는 계정');
      } else {
        console.log(`실패: ${result.message || result.msg || JSON.stringify(result)}`);
      }
    } catch (e) {
      console.log(`오류: ${e.message}`);
    }
  }

  console.log('\n[INFO] 관리자(mediacube) UUID 조회 중...');
  const adminId = await getAdminId(svcKey);
  if (adminId) {
    console.log(`[OK]  mediacube UUID: ${adminId}`);
    console.log('\n========================================');
    console.log('아래 SQL을 Supabase SQL Editor에서 실행하세요:');
    console.log('========================================\n');
    console.log(`-- ① user_id 컬럼 추가
ALTER TABLE journals ADD COLUMN IF NOT EXISTS user_id UUID;

-- ② RLS 활성화
ALTER TABLE journals ENABLE ROW LEVEL SECURITY;

-- ③ 기존 정책 초기화
DROP POLICY IF EXISTS "own_journals" ON journals;
DROP POLICY IF EXISTS "admin_all" ON journals;

-- ④ 각자 본인 일지만 조회·수정
CREATE POLICY "own_journals" ON journals FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ⑤ 관리자(mediacube)는 전체 조회·수정
CREATE POLICY "admin_all" ON journals FOR ALL
  USING (auth.email() = 'mediacube@mediacube.com')
  WITH CHECK (auth.email() = 'mediacube@mediacube.com');

-- ⑥ 기존 일지를 mediacube 계정으로 귀속
UPDATE journals SET user_id = '${adminId}' WHERE user_id IS NULL;`);
  } else {
    console.log('[WARN] mediacube UUID를 찾지 못했습니다. 직접 Supabase 대시보드에서 확인하세요.');
  }
}

main().catch(console.error);
