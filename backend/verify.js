// READ-ONLY: verify live rules + fetch the app's google-services.json config.
const { GoogleAuth } = require('google-auth-library');
const sa = require('./serviceAccountKey.json');
(async () => {
  const auth = new GoogleAuth({ credentials: sa, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const client = await auth.getClient();
  const P = sa.project_id;
  console.log('service account project:', P, '\n');

  // --- 1. live Firestore rules
  const rel = await client.request({ url: `https://firebaserules.googleapis.com/v1/projects/${P}/releases/cloud.firestore` });
  const rs = await client.request({ url: `https://firebaserules.googleapis.com/v1/${rel.data.rulesetName}` });
  const src = rs.data.source.files[0].content;
  const hasChats = src.includes('/chats/{chatId}');
  const denyAll = /match \/\{document=\*\*\}[\s\S]*?allow read, write: if false/.test(src);
  console.log('RULES: chats rule present :', hasChats ? '✅' : '❌');
  console.log('RULES: default deny intact:', denyAll ? '✅' : '❌');
  console.log('RULES: updated at         :', rel.data.updateTime);

  // --- 2. the Android app config (this IS google-services.json)
  const apps = await client.request({ url: `https://firebase.googleapis.com/v1beta1/projects/${P}/androidApps` });
  for (const a of apps.data.apps || []) {
    console.log('\nAPP:', a.packageName, '|', a.appId);
    const cfg = await client.request({ url: `https://firebase.googleapis.com/v1beta1/${a.name}/config` });
    const json = Buffer.from(cfg.data.configFileContents, 'base64').toString('utf8');
    require('fs').writeFileSync('fresh-google-services.json', json);
    const g = JSON.parse(json);
    const oauth = g.client[0].oauth_client || [];
    console.log('  oauth clients:', oauth.length ? oauth.map(o => 'type' + o.client_type).join(', ') : 'NONE');
    const android = oauth.filter(o => o.client_type === 1);
    console.log('  android OAuth (needed for Google Sign-In):', android.length ? '✅ ' + android.length + ' present' : '❌ MISSING');
    android.forEach(o => console.log('     sha1:', o.android_info?.certificate_hash));
  }
})().catch(e => console.log('ERR:', e.response?.data?.error?.message || e.message));
