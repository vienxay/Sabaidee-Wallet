/**
 * ທົດສອບການເຊື່ອມຕໍ່ LNBits
 * 
 * ວິທີໃຊ້:
 * 1. ບັນທຶກໄຟລ໌ນີ້ໄວ້ໃນ project folder
 * 2. Run: node test-lnbits.js
 */

const https = require('https');

// ========================================
// ຕັ້ງຄ່າ - ແກ້ໄຂຕາມ .env ຂອງທ່ານ
// ========================================
const CONFIG = {
  LNBITS_URL: 'https://lnbits.sabaideeln.com',
  MAIN_WALLET_KEY: 'b50593e9638343c5b90f9afa1a77a736',
  POOL_WALLET_KEY: '0e4317dbce3f430c9c133a490c93b58a',
};

// ========================================
// Functions
// ========================================

function makeRequest(url, apiKey) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    
    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname,
      method: 'GET',
      headers: {
        'X-Api-Key': apiKey,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        resolve({
          status: res.statusCode,
          headers: res.headers,
          body: data,
        });
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    req.end();
  });
}

async function testConnection() {
  console.log('========================================');
  console.log('🔍 ທົດສອບການເຊື່ອມຕໍ່ LNBits');
  console.log('========================================');
  console.log(`URL: ${CONFIG.LNBITS_URL}`);
  console.log('');

  // Test 1: Main Wallet
  console.log('📌 Test 1: Main Wallet');
  console.log(`   Key: ${CONFIG.MAIN_WALLET_KEY.substring(0, 10)}...`);
  
  try {
    const result1 = await makeRequest(
      `${CONFIG.LNBITS_URL}/api/v1/wallet`,
      CONFIG.MAIN_WALLET_KEY
    );
    
    console.log(`   Status: ${result1.status}`);
    
    if (result1.status === 200) {
      const data = JSON.parse(result1.body);
      console.log(`   ✅ ສຳເລັດ!`);
      console.log(`   Wallet ID: ${data.id}`);
      console.log(`   Wallet Name: ${data.name}`);
      console.log(`   Balance: ${data.balance / 1000} sats`);
    } else if (result1.body.includes('<!DOCTYPE html>')) {
      console.log(`   ❌ Server Error (HTML response)`);
      if (result1.body.includes('520')) {
        console.log(`   Error: 520 - Web server is returning an unknown error`);
      } else if (result1.body.includes('502')) {
        console.log(`   Error: 502 - Bad Gateway`);
      } else if (result1.body.includes('503')) {
        console.log(`   Error: 503 - Service Unavailable`);
      }
    } else {
      console.log(`   ❌ Error: ${result1.body}`);
    }
  } catch (error) {
    console.log(`   ❌ Connection Error: ${error.message}`);
  }

  console.log('');

  // Test 2: Pool Wallet
  console.log('📌 Test 2: Pool Wallet (Admin)');
  console.log(`   Key: ${CONFIG.POOL_WALLET_KEY.substring(0, 10)}...`);
  
  try {
    const result2 = await makeRequest(
      `${CONFIG.LNBITS_URL}/api/v1/wallet`,
      CONFIG.POOL_WALLET_KEY
    );
    
    console.log(`   Status: ${result2.status}`);
    
    if (result2.status === 200) {
      const data = JSON.parse(result2.body);
      console.log(`   ✅ ສຳເລັດ!`);
      console.log(`   Wallet ID: ${data.id}`);
      console.log(`   Wallet Name: ${data.name}`);
      console.log(`   Balance: ${data.balance / 1000} sats`);
    } else if (result2.body.includes('<!DOCTYPE html>')) {
      console.log(`   ❌ Server Error`);
    } else {
      console.log(`   ❌ Error: ${result2.body}`);
    }
  } catch (error) {
    console.log(`   ❌ Connection Error: ${error.message}`);
  }

  console.log('');

  // Test 3: Create Invoice (Pool Wallet)
  console.log('📌 Test 3: ສ້າງ Invoice ຈາກ Pool Wallet');
  
  try {
    const invoiceResult = await createTestInvoice();
    if (invoiceResult.success) {
      console.log(`   ✅ ສຳເລັດ!`);
      console.log(`   Payment Hash: ${invoiceResult.payment_hash}`);
      console.log(`   Invoice: ${invoiceResult.payment_request.substring(0, 50)}...`);
    } else {
      console.log(`   ❌ Error: ${invoiceResult.error}`);
    }
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
  }

  console.log('');
  console.log('========================================');
  console.log('🏁 ທົດສອບສຳເລັດ');
  console.log('========================================');
}

function createTestInvoice() {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(`${CONFIG.LNBITS_URL}/api/v1/payments`);
    
    const postData = JSON.stringify({
      out: false,
      amount: 1,
      memo: 'Test Invoice',
      unit: 'sat',
    });

    const options = {
      hostname: urlObj.hostname,
      port: 443,
      path: urlObj.pathname,
      method: 'POST',
      headers: {
        'X-Api-Key': CONFIG.POOL_WALLET_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
      timeout: 15000,
    };

    const req = https.request(options, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode === 201 || res.statusCode === 200) {
          try {
            const parsed = JSON.parse(data);
            resolve({ success: true, ...parsed });
          } catch (e) {
            resolve({ success: false, error: 'Invalid JSON response' });
          }
        } else {
          resolve({ success: false, error: data });
        }
      });
    });

    req.on('error', (error) => {
      resolve({ success: false, error: error.message });
    });

    req.on('timeout', () => {
      req.destroy();
      resolve({ success: false, error: 'Request timeout' });
    });

    req.write(postData);
    req.end();
  });
}

// Run test
testConnection();