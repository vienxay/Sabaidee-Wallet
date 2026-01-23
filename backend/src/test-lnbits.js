const https = require('https');

const CONFIG = {
  LNBITS_URL: 'https://lnbits.sabaideeln.com',
  MAIN_WALLET_KEY: 'b50593e9638343c5b90f9afa1a77a736',
  POOL_WALLET_KEY: '0e4317dbce3f430c9c133a490c93b58a',
};

function testWallet(name, apiKey) {
  return new Promise((resolve) => {
    const req = https.request({
      hostname: 'lnbits.sabaideeln.com',
      path: '/api/v1/wallet',
      method: 'GET',
      headers: { 'X-Api-Key': apiKey },
      timeout: 15000,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        console.log(`\n📌 ${name}`);
        console.log(`   Status: ${res.statusCode}`);
        if (res.statusCode === 200) {
          const json = JSON.parse(data);
          console.log(`   ✅ ສຳເລັດ!`);
          console.log(`   Balance: ${json.balance / 1000} sats`);
        } else {
          console.log(`   ❌ Error`);
        }
        resolve();
      });
    });
    req.on('error', (e) => {
      console.log(`\n📌 ${name}`);
      console.log(`   ❌ Connection Error: ${e.message}`);
      resolve();
    });
    req.end();
  });
}

async function run() {
  console.log('🔍 ທົດສອບ LNBits Connection...');
  await testWallet('Main Wallet', CONFIG.MAIN_WALLET_KEY);
  await testWallet('Pool Wallet', CONFIG.POOL_WALLET_KEY);
  console.log('\n✅ Done!');
}

run();