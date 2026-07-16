// READ-ONLY database integrity audit. Changes nothing.
const prisma = require('./src/utils/prisma');

const issues = [];
const flag = (sev, what) => { issues.push({ sev, what }); console.log(`  ${sev === 'HIGH' ? '🔴' : sev === 'MED' ? '🟠' : '🟡'} ${what}`); };
const good = (what) => console.log(`  ✅ ${what}`);

(async () => {
  console.log('\n=== 1. ORPHANED / INCONSISTENT ROWS ===');

  const providersNoProfile = await prisma.user.count({ where: { role: 'PROVIDER', provider_profile: null } });
  providersNoProfile
    ? flag('HIGH', `${providersNoProfile} PROVIDER user(s) have NO provider_profile -> dashboard/toggle/wallet all break for them`)
    : good('every PROVIDER has a profile');

  const noFirebaseUid = await prisma.user.count({ where: { firebaseUid: null } });
  noFirebaseUid
    ? flag('MED', `${noFirebaseUid} user(s) have no firebaseUid -> they can never sign in`)
    : good('every user has a firebaseUid');

  // the two verified flags must agree; job matching reads the profile one
  const mismatch = await prisma.$queryRawUnsafe(`
    SELECT COUNT(*)::int AS n FROM "User" u
    JOIN "ProviderProfile" p ON p.user_id = u.id
    WHERE u.is_verified <> p.is_verified;`);
  mismatch[0].n
    ? flag('HIGH', `${mismatch[0].n} provider(s) have User.is_verified != ProviderProfile.is_verified -> admin sees a tick but they get no jobs`)
    : good('User.is_verified and ProviderProfile.is_verified agree everywhere');

  const onlineUnverified = await prisma.providerProfile.count({ where: { is_online: true, is_verified: false } });
  onlineUnverified
    ? flag('LOW', `${onlineUnverified} provider(s) are Available but unverified -> they see no jobs and may think the app is broken`)
    : good('no provider is Available-but-unverified');

  const blockedOnline = await prisma.providerProfile.count({ where: { is_online: true, user: { OR: [{ is_blocked: true }, { deleted_at: { not: null } }] } } });
  blockedOnline
    ? flag('HIGH', `${blockedOnline} BLOCKED/DELETED provider(s) still flagged online`)
    : good('no blocked/deleted provider is online');

  console.log('\n=== 2. MONEY ===');

  const negWallets = await prisma.providerProfile.findMany({
    where: { wallet_balance: { lt: 0 } },
    select: { wallet_balance: true, user: { select: { name: true, email: true } } },
  });
  if (negWallets.length) {
    flag('MED', `${negWallets.length} provider(s) owe commission (negative wallet) — they are blocked from new work until they top up:`);
    negWallets.forEach(p => console.log(`        ${p.user.name} (${p.user.email}): Rs. ${p.wallet_balance}`));
  } else good('no provider has a negative wallet');

  // Does every COMPLETED booking have a commission ledger row?
  const completed = await prisma.booking.count({ where: { status: 'COMPLETED' } });
  const commissionTxns = await prisma.transaction.count({ where: { type: 'COMMISSION' } });
  if (completed > commissionTxns) {
    flag('HIGH', `${completed} completed booking(s) but only ${commissionTxns} commission ledger row(s) -> commission was NOT charged on ${completed - commissionTxns} job(s)`);
  } else good(`commission charged on every completed job (${completed} completed, ${commissionTxns} ledger rows)`);

  const zeroPrice = await prisma.booking.count({ where: { total_amount: { lte: 0 }, status: { in: ['ACCEPTED', 'ONGOING', 'COMPLETED'] } } });
  zeroPrice
    ? flag('HIGH', `${zeroPrice} accepted/completed booking(s) with price <= 0 -> zero commission, free job`)
    : good('no accepted/completed booking priced at zero');

  console.log('\n=== 3. BOOKING STATE MACHINE ===');

  const ongoingNoOtp = await prisma.booking.count({ where: { status: 'ONGOING', started_at: null } });
  ongoingNoOtp
    ? flag('HIGH', `${ongoingNoOtp} ONGOING booking(s) with no started_at -> the OTP lock was bypassed`)
    : good('every ONGOING booking passed the start-OTP lock');

  const completedNoOtp = await prisma.booking.count({ where: { status: 'COMPLETED', completed_at: null } });
  completedNoOtp
    ? flag('HIGH', `${completedNoOtp} COMPLETED booking(s) with no completed_at -> the completion-OTP lock was bypassed`)
    : good('every COMPLETED booking passed the completion-OTP lock');

  const completedNoPhotos = await prisma.booking.count({ where: { status: 'COMPLETED', OR: [{ before_photo: null }, { after_photo: null }] } });
  completedNoPhotos
    ? flag('MED', `${completedNoPhotos} COMPLETED booking(s) missing a before/after photo -> no proof of work`)
    : good('every completed job has before + after photos');

  // A provider can only do one job at a time.
  const busy = await prisma.$queryRawUnsafe(`
    SELECT provider_id, COUNT(*)::int AS n FROM "Booking"
    WHERE status IN ('ACCEPTED','ONGOING') GROUP BY provider_id HAVING COUNT(*) > 1;`);
  busy.length
    ? flag('HIGH', `${busy.length} provider(s) hold MORE THAN ONE active job at once -> the "one job at a time" rule leaked`)
    : good('no provider holds two active jobs');

  // An OPEN job that already has an accepted booking should have been closed.
  const leaked = await prisma.$queryRawUnsafe(`
    SELECT COUNT(DISTINCT j.id)::int AS n FROM "JobPost" j
    JOIN "Booking" b ON b.job_post_id = j.id
    WHERE j.status = 'OPEN' AND b.status IN ('ACCEPTED','ONGOING','COMPLETED');`);
  leaked[0].n
    ? flag('HIGH', `${leaked[0].n} job(s) still OPEN despite an accepted booking -> other providers can still quote on a taken job`)
    : good('every job with an accepted booking is closed');

  console.log('\n=== 4. STALE RESCHEDULE ===');
  const stale = await prisma.booking.count({
    where: { reschedule_proposed_at: { not: null }, reschedule_requested_at: { lt: new Date(Date.now() - 24 * 3600 * 1000) } },
  });
  stale
    ? flag('LOW', `${stale} reschedule proposal(s) older than 24h still pending -> the scheduler will clear these on its next sweep`)
    : good('no stale reschedule proposals');

  const orphanProposal = await prisma.booking.count({
    where: { reschedule_proposed_at: { not: null }, reschedule_requested_at: null },
  });
  orphanProposal
    ? flag('MED', `${orphanProposal} proposal(s) with no requested_at (made before the column existed) -> they can never expire`)
    : good('every pending proposal has a requested_at');

  console.log('\n=== 5. INDEXES on the hot paths ===');
  const idx = await prisma.$queryRawUnsafe(`
    SELECT tablename, indexdef FROM pg_indexes
    WHERE schemaname='public' AND tablename IN ('Booking','JobPost','ProviderProfile','Notification','Transaction');`);
  const has = (table, col) => idx.some(i => i.tablename === table && i.indexdef.includes(`(${col}`) || (i.tablename === table && i.indexdef.includes(`, ${col}`)));
  const wanted = [
    ['Booking', 'provider_id'], ['Booking', 'customer_id'], ['Booking', 'status'],
    ['JobPost', 'status'], ['Notification', 'user_id'], ['Transaction', 'user_id'],
  ];
  for (const [t, c] of wanted) {
    has(t, c) ? good(`${t}.${c} indexed`) : flag('MED', `${t}.${c} has NO index -> full table scan on every query that filters by it`);
  }

  console.log('\n=== 6. DATA HYGIENE ===');
  const junkNames = await prisma.user.count({ where: { OR: [{ name: 'New User' }, { name: 'Provider' }, { name: '' }] } });
  junkNames
    ? flag('LOW', `${junkNames} user(s) still have a placeholder name -> they show up as "New User" to the other side`)
    : good('no placeholder names');

  const noServices = await prisma.category.count({ where: { services: { none: {} }, name: { not: 'Uncategorized' } } });
  noServices
    ? flag('MED', `${noServices} category(ies) have NO services -> a customer taps them and nothing happens`)
    : good('every customer-visible category has at least one service');

  const svcNoFence = await prisma.service.count({ where: { OR: [{ min_price: null }, { max_price: null }] } });
  svcNoFence
    ? flag('LOW', `${svcNoFence} service(s) have no min/max price -> providers may quote any amount on them`)
    : good('every service has a bid fence');

  console.log('\n' + '='.repeat(60));
  const high = issues.filter(i => i.sev === 'HIGH').length;
  const med = issues.filter(i => i.sev === 'MED').length;
  const low = issues.filter(i => i.sev === 'LOW').length;
  console.log(`DB AUDIT: ${high} high, ${med} medium, ${low} low`);
  process.exit(0);
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
