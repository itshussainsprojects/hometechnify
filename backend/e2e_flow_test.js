/**
 * E2E FLOW TEST — customer → nearest/best-rated providers → job post →
 * provider sees job → provider quotes → customer sees offer.
 * Wallet stays DUMMY (dev mock top-up only; no gateway).
 *
 * Run: node e2e_flow_test.js   (server must be running on :3000)
 */
require('dotenv').config();
const admin = require('firebase-admin');
const axios = require('axios');
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

admin.initializeApp({ credential: admin.credential.cert(require('./serviceAccountKey.json')) });

const API = 'http://localhost:3000/api';
const FIREBASE_API_KEY = 'AIzaSyDqs-JjGwwuAJ49hZkhCwQGsOFbgALw9Kw';

// Customer test location: Gulshan-e-Iqbal, Karachi
const CUST = { lat: 24.9180, lng: 67.0971 };

const PROVIDERS = [
    { uid: 'e2e-prov-near-good', name: 'E2E Plumber NearGood', rating: 4.8, lat: 24.9250, lng: 67.1030, verified: true,  jobs: 40 }, // ~1 km
    { uid: 'e2e-prov-near-bad',  name: 'E2E Plumber NearBad',  rating: 2.4, lat: 24.9200, lng: 67.1000, verified: false, jobs: 3  }, // ~0.4 km
    { uid: 'e2e-prov-far-good',  name: 'E2E Plumber FarGood',  rating: 4.9, lat: 25.1100, lng: 67.2800, verified: true,  jobs: 80 }, // ~28 km
];
const CUST_UID = 'e2e-cust-flow-test';

let pass = 0, fail = 0;
const check = (label, cond, extra = '') => {
    if (cond) { pass++; console.log(`  ✅ ${label} ${extra}`); }
    else { fail++; console.log(`  ❌ ${label} ${extra}`); }
};

// email/password test accounts (custom-token exchange fails: local service
// key can't sign tokens the project accepts, so we use real signup/sign-in)
async function idTokenFor(uid) {
    const email = `${uid.replace(/[^a-z0-9-]/gi, '')}@e2etest.com`;
    const password = 'E2eTest12345!';
    const base = 'https://identitytoolkit.googleapis.com/v1/accounts';
    try {
        const r = await axios.post(`${base}:signUp?key=${FIREBASE_API_KEY}`, { email, password, returnSecureToken: true });
        return { idToken: r.data.idToken, fbUid: r.data.localId };
    } catch (e) {
        if (e.response?.data?.error?.message === 'EMAIL_EXISTS') {
            const r = await axios.post(`${base}:signInWithPassword?key=${FIREBASE_API_KEY}`, { email, password, returnSecureToken: true });
            return { idToken: r.data.idToken, fbUid: r.data.localId };
        }
        throw e;
    }
}
const authed = (token) => axios.create({ baseURL: API, headers: { Authorization: `Bearer ${token}` }, validateStatus: () => true });

async function main() {
    console.log('\n========= SETUP (database seeding) =========');
    const plumbing = await prisma.category.findFirst({ where: { name: { equals: 'plumbing', mode: 'insensitive' } } });
    if (!plumbing) throw new Error('No plumbing category in DB');
    let service = await prisma.service.findFirst({ where: { category_id: plumbing.id } });
    if (!service) {
        service = await prisma.service.create({ data: { name: 'General Plumbing', category_id: plumbing.id, base_price: 500, description: 'e2e', duration_minutes: 60 } });
    }
    console.log(`Category: ${plumbing.name} (${plumbing.id})  Service: ${service.name}`);

    // --- tokens + sync users through the real API (tests /auth/sync too)
    const { idToken: custToken } = await idTokenFor(CUST_UID);
    const custApi = authed(custToken);
    let r = await custApi.post('/auth/sync', { name: 'E2E Flow Customer', role: 'CUSTOMER', email: 'e2eflowcust@t.com' });
    check('customer /auth/sync', r.status < 300, `(${r.status})`);

    const provApis = [];
    for (const p of PROVIDERS) {
        const { idToken: t, fbUid } = await idTokenFor(p.uid);
        const api = authed(t);
        r = await api.post('/auth/sync', { name: p.name, role: 'PROVIDER', email: `${p.uid}@t.com` });
        check(`provider sync ${p.name}`, r.status < 300, `(${r.status})`);
        // Seed profile directly (onboarding UI shortcut) — category, rating, location
        const user = await prisma.user.findUnique({ where: { firebaseUid: fbUid } });
        await prisma.providerProfile.upsert({
            where: { user_id: user.id },
            create: {
                user_id: user.id, service_category_id: plumbing.id, hourly_rate: 800,
                rating: p.rating, is_online: true, is_verified: p.verified,
                current_lat: p.lat, current_lng: p.lng, jobs_completed: p.jobs,
            },
            update: {
                service_category_id: plumbing.id, rating: p.rating, is_online: true,
                is_verified: p.verified, current_lat: p.lat, current_lng: p.lng, jobs_completed: p.jobs,
            },
        });
        provApis.push({ ...p, api, dbId: user.id });
    }

    // Admin account (role set via DB, like makeAdmin.js — clients can't self-grant ADMIN)
    const { idToken: admToken, fbUid: admUid } = await idTokenFor('e2e-admin-flow');
    const admApi = authed(admToken);
    r = await admApi.post('/auth/sync', { name: 'E2E Admin', role: 'CUSTOMER' });
    await prisma.user.update({ where: { firebaseUid: admUid }, data: { role: 'ADMIN' } });
    check('admin user ready', r.status < 300);

    // Deterministic platform settings for this run
    for (const [key, value] of [['commission_percent', '12'], ['provider_radius_km', '20']]) {
        await prisma.appSetting.upsert({ where: { key }, update: { value }, create: { key, value } });
    }

    console.log('\n========= 1) CUSTOMER: nearest + best-rated plumbers =========');
    r = await custApi.get('/providers', { params: { categoryId: 'plumbing', available: 'true', lat: CUST.lat, lng: CUST.lng } });
    check('GET /providers 200', r.status === 200);
    const list = (r.data.data || []).filter(u => u.name.startsWith('E2E Plumber'));
    list.forEach((u, i) => console.log(`  #${i + 1} ${u.name}  rating=${u.provider_profile.rating}  dist=${u.distance_km?.toFixed(1)}km  verified=${u.provider_profile.is_verified}`));
    check('near+high-rated ranked first', list[0]?.name === 'E2E Plumber NearGood');
    check('inDrive radius: far provider (28km) filtered out', list.length === 2 && !list.some(u => u.name === 'E2E Plumber FarGood'), `(got ${list.length})`);
    check('no far provider on top', list[0]?.distance_km < 5);

    console.log('\n========= 1b) ADMIN: radius change applies live =========');
    r = await admApi.put('/admin/settings/platform', { provider_radius_km: 50 });
    check('admin sets radius 50km', r.status === 200);
    r = await custApi.get('/providers', { params: { categoryId: 'plumbing', available: 'true', lat: CUST.lat, lng: CUST.lng } });
    const wide = (r.data.data || []).filter(u => u.name.startsWith('E2E Plumber'));
    check('far provider appears at 50km radius (no restart)', wide.some(u => u.name === 'E2E Plumber FarGood'), `(got ${wide.length})`);
    r = await admApi.put('/admin/settings/platform', { provider_radius_km: 20 });
    check('admin resets radius 20km', r.status === 200);

    console.log('\n========= 2) CUSTOMER: post plumbing job =========');
    r = await custApi.post('/jobs', { title: 'Kitchen sink leak repair', description: 'Sink pipe leaking badly, need urgent fix', budget: 1500, location: 'Gulshan-e-Iqbal Block 13, Karachi', serviceId: service.id, lat: CUST.lat, lng: CUST.lng });
    check('POST /jobs 201', r.status === 201, `(${r.status})`);
    const job = r.data;
    check('job category resolved to plumbing', (job.category || '').toLowerCase() === 'plumbing', `-> "${job.category}"`);
    check('job saved with real lat/lng', job.lat === CUST.lat && job.lng === CUST.lng, `(${job.lat}, ${job.lng})`);
    console.log(`  Job ID: ${job.id}  status=${job.status}`);

    console.log('\n========= 3) PROVIDER: sees the job in nearby feed =========');
    const prov = provApis[0]; // NearGood
    r = await prov.api.get('/jobs/nearby');
    check('GET /jobs/nearby 200', r.status === 200);
    const found = (r.data || []).find(j => j.id === job.id);
    check('plumber sees the plumbing job', !!found, found ? `"${found.title}"` : '');

    // sanity: a cleaning provider should NOT see it — use category param directly
    r = await prov.api.get('/jobs/nearby', { params: { category: 'cleaning' } });
    const wrongCat = (r.data || []).find(j => j.id === job.id);
    check('cleaning feed does NOT show plumbing job', !wrongCat);

    console.log('\n========= 4) PROVIDER: quote (bid) on the job =========');
    const walletBefore = (await prisma.providerProfile.findUnique({ where: { user_id: prov.dbId } })).wallet_balance;
    r = await prov.api.post(`/jobs/${job.id}/accept`, { price: 1800 });
    check('POST /jobs/:id/accept 201', r.status === 201, `(${r.status})`);
    const booking = r.data.data;
    check('booking status NEGOTIATING', booking?.status === 'NEGOTIATING');
    check('quote amount = 1800', booking?.total_amount === 1800);
    check('last_offer_by PROVIDER', booking?.last_offer_by === 'PROVIDER');
    check('booking has real job-site lat/lng (not 0.0)', booking?.lat === CUST.lat && booking?.lng === CUST.lng, `(${booking?.lat}, ${booking?.lng})`);

    // second provider also bids — job stays OPEN for multiple quotes
    r = await provApis[2].api.post(`/jobs/${job.id}/accept`, { price: 1400 });
    check('2nd provider can also bid (multi-quote)', r.status === 201);
    const jobAfter = await prisma.jobPost.findUnique({ where: { id: job.id } });
    check('job still OPEN after bids', jobAfter.status === 'OPEN');

    console.log('\n========= 5) CUSTOMER: sees the offers =========');
    r = await custApi.get('/bookings/my');
    check('GET /bookings/my 200', r.status === 200);
    const myBookings = (r.data.data || r.data || []);
    const offers = myBookings.filter(b => b.job_post_id === job.id);
    check('customer sees 2 offers for the job', offers.length === 2, `(got ${offers.length})`);
    offers.forEach(o => console.log(`  Offer: Rs.${o.total_amount} status=${o.status} provider=${o.provider?.name || o.provider_id}`));

    console.log('\n========= 6) WALLET: dummy top-up check =========');
    const walletAfter = (await prisma.providerProfile.findUnique({ where: { user_id: prov.dbId } })).wallet_balance;
    check('wallet untouched by quoting', walletBefore === walletAfter, `(Rs.${walletBefore} -> Rs.${walletAfter})`);
    r = await prov.api.post('/providers/wallet/topup', { amount: 500, payment_method: 'JAZZCASH' });
    check('dev-mock top-up works (no gateway)', r.status < 300, `(${r.status})`);
    const walletTop = (await prisma.providerProfile.findUnique({ where: { user_id: prov.dbId } })).wallet_balance;
    check('balance +500 after mock top-up', walletTop === walletAfter + 500, `(Rs.${walletTop})`);

    console.log('\n========= 7) FULL JOB CYCLE + COMMISSION (12%) =========');
    // Customer accepts NearGood's Rs.1800 offer → OTP work-lock → complete → commission deducted
    const bkId = offers.find(o => o.total_amount === 1800).id;
    r = await custApi.put(`/bookings/${bkId}/accept-offer`);
    check('customer accepts offer (ACCEPTED)', r.status === 200, `(${r.status})`);
    r = await prov.api.put(`/bookings/${bkId}/arrived`, { lat: CUST.lat, lng: CUST.lng });
    check('provider marks arrived', r.status === 200, `(${r.status})`);
    let bkDb = await prisma.booking.findUnique({ where: { id: bkId } });
    r = await prov.api.put(`/bookings/${bkId}/start`, { otp: bkDb.start_otp, beforePhoto: 'https://e2e.test/before.jpg' });
    check('start with OTP + before photo (ONGOING)', r.status === 200, `(${r.status})`);
    bkDb = await prisma.booking.findUnique({ where: { id: bkId } });
    const wBeforeDone = (await prisma.providerProfile.findUnique({ where: { user_id: prov.dbId } })).wallet_balance;
    r = await prov.api.put(`/bookings/${bkId}/complete`, { otp: bkDb.completion_otp, afterPhoto: 'https://e2e.test/after.jpg' });
    check('complete with OTP + after photo (COMPLETED)', r.status === 200, `(${r.status})`);
    const wAfterDone = (await prisma.providerProfile.findUnique({ where: { user_id: prov.dbId } })).wallet_balance;
    const expected12 = 1800 * 0.12;
    check(`commission 12% (Rs.${expected12}) auto-deducted from wallet`, Math.abs((wBeforeDone - wAfterDone) - expected12) < 0.01, `(Rs.${wBeforeDone} -> Rs.${wAfterDone})`);
    const commTx = await prisma.transaction.findFirst({ where: { user_id: prov.dbId, type: 'COMMISSION' }, orderBy: { created_at: 'desc' } });
    check('COMMISSION transaction recorded (admin finance)', !!commTx && Math.abs(commTx.amount - expected12) < 0.01, commTx ? `Rs.${commTx.amount}` : '');

    console.log('\n========= 8) ADMIN changes commission → applies to ALL providers =========');
    r = await admApi.put('/admin/settings/platform', { commission_percent: 10 });
    check('admin sets commission 10%', r.status === 200);
    // A DIFFERENT provider (FarGood) completes his Rs.1400 booking — new rate applies with no restart
    const far = provApis[2];
    const bk2Id = offers.find(o => o.total_amount === 1400).id;
    await custApi.put(`/bookings/${bk2Id}/accept-offer`);
    await far.api.put(`/bookings/${bk2Id}/arrived`, { lat: CUST.lat, lng: CUST.lng });
    let bk2Db = await prisma.booking.findUnique({ where: { id: bk2Id } });
    await far.api.put(`/bookings/${bk2Id}/start`, { otp: bk2Db.start_otp, beforePhoto: 'https://e2e.test/b2.jpg' });
    bk2Db = await prisma.booking.findUnique({ where: { id: bk2Id } });
    const wFarBefore = (await prisma.providerProfile.findUnique({ where: { user_id: far.dbId } })).wallet_balance;
    r = await far.api.put(`/bookings/${bk2Id}/complete`, { otp: bk2Db.completion_otp, afterPhoto: 'https://e2e.test/a2.jpg' });
    check('2nd provider completes job', r.status === 200, `(${r.status})`);
    const wFarAfter = (await prisma.providerProfile.findUnique({ where: { user_id: far.dbId } })).wallet_balance;
    const expected10 = 1400 * 0.10;
    check(`NEW 10% rate applied automatically (Rs.${expected10})`, Math.abs((wFarBefore - wFarAfter) - expected10) < 0.01, `(Rs.${wFarBefore} -> Rs.${wFarAfter})`);

    console.log('\n========= 9) NEGATIVE WALLET → blocked from new jobs =========');
    const bad = provApis[1]; // NearBad
    await prisma.providerProfile.update({ where: { user_id: bad.dbId }, data: { wallet_balance: -50 } });
    r = await custApi.post('/jobs', { title: 'Bathroom tap fix', description: 'Tap dripping', budget: 800, location: 'Gulshan, Karachi', serviceId: service.id, lat: CUST.lat, lng: CUST.lng });
    const job2 = r.data;
    r = await bad.api.post(`/jobs/${job2.id}/accept`, { price: 700 });
    check('negative-wallet provider blocked from quoting (403)', r.status === 403 && r.data.code === 'WALLET_TOPUP_REQUIRED', `(${r.status})`);
    await bad.api.post('/providers/wallet/topup', { amount: 500, payment_method: 'JAZZCASH' });
    r = await bad.api.post(`/jobs/${job2.id}/accept`, { price: 700 });
    check('after top-up he can quote again', r.status === 201, `(${r.status})`);
    await prisma.booking.deleteMany({ where: { job_post_id: job2.id } });
    await prisma.jobPost.delete({ where: { id: job2.id } });

    console.log('\n========= ADMIN: job/booking visible in DB =========');
    const adminJob = await prisma.jobPost.findUnique({ where: { id: job.id }, include: { bookings: true } });
    check('admin/DB: job has 2 linked bookings', adminJob.bookings.length === 2);

    console.log(`\n================ RESULT: ${pass} passed, ${fail} failed ================\n`);

    // cleanup test job + bookings (keep users for re-runs); restore settings
    await prisma.booking.deleteMany({ where: { job_post_id: job.id } });
    await prisma.jobPost.delete({ where: { id: job.id } });
    await prisma.appSetting.update({ where: { key: 'commission_percent' }, data: { value: '12' } });
    console.log('Cleanup done (test job + bookings removed, commission reset to 12%).');
    await prisma.$disconnect();
    process.exit(fail ? 1 : 0);
}

main().catch(e => { console.error('FATAL:', e.response?.data || e); process.exit(1); });
