/**
 * Bank Transfer Service
 * ໂອນເງິນກີບຈາກ Sabaidee Wallet (ບັນຊີບໍລິສັດ) ໄປຫາຮ້ານຄ້າ
 * 
 * ⚠️ TODO: ໃສ່ Bank API ຕົວຈິງ (BCEL, JDB, LDB)
 */

const axios = require('axios');

class BankTransferService {
  constructor() {
    // BCEL API Config
    this.bcelConfig = {
      baseURL: process.env.BCEL_API_URL,
      merchantId: process.env.BCEL_MERCHANT_ID,
      apiKey: process.env.BCEL_API_KEY,
      secretKey: process.env.BCEL_SECRET_KEY,
    };

    // JDB API Config  
    this.jdbConfig = {
      baseURL: process.env.JDB_API_URL,
      merchantId: process.env.JDB_MERCHANT_ID,
      apiKey: process.env.JDB_API_KEY,
    };

    // LDB API Config
    this.ldbConfig = {
      baseURL: process.env.LDB_API_URL,
      merchantId: process.env.LDB_MERCHANT_ID,
      apiKey: process.env.LDB_API_KEY,
    };
  }

  /**
   * ໂອນເງິນອັດຕະໂນມັດຕາມທະນາຄານ
   */
  async transfer(bankName, accountNumber, accountName, amount, reference) {
    console.log(`\n🏦 === BANK TRANSFER ===`);
    console.log(`📍 From: Sabaidee Wallet (Company Account)`);
    console.log(`📍 To: ${accountName} (${bankName})`);
    console.log(`📍 Account: ${accountNumber}`);
    console.log(`💰 Amount: ${amount.toLocaleString()} LAK`);
    console.log(`📝 Reference: ${reference}`);

    try {
      let result;
      
      switch (bankName.toUpperCase()) {
        case 'BCEL':
          result = await this.transferBCEL(accountNumber, accountName, amount, reference);
          break;
        case 'JDB':
          result = await this.transferJDB(accountNumber, accountName, amount, reference);
          break;
        case 'LDB':
          result = await this.transferLDB(accountNumber, accountName, amount, reference);
          break;
        default:
          // ສຳລັບທະນາຄານອື່ນ, ໃຊ້ mock
          result = await this.mockTransfer(bankName, accountNumber, amount, reference);
      }

      console.log(`✅ Transfer successful: ${result.referenceNumber}`);
      return result;

    } catch (error) {
      console.error(`❌ Transfer failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * BCEL Transfer
   * TODO: ໃສ່ BCEL One API ຕົວຈິງ
   */
  async transferBCEL(accountNumber, accountName, amount, reference) {
    // ຖ້າມີ API config, ໃຊ້ API ຕົວຈິງ
    if (this.bcelConfig.apiKey && this.bcelConfig.baseURL) {
      try {
        const response = await axios.post(
          `${this.bcelConfig.baseURL}/api/v1/transfer`,
          {
            merchantId: this.bcelConfig.merchantId,
            toAccount: accountNumber,
            toName: accountName,
            amount: amount,
            currency: 'LAK',
            reference: reference,
          },
          {
            headers: {
              'Authorization': `Bearer ${this.bcelConfig.apiKey}`,
              'Content-Type': 'application/json',
            },
            timeout: 30000,
          }
        );

        return {
          success: true,
          referenceNumber: response.data.transactionId || response.data.reference,
          bankReference: response.data.bankReference,
          transferredAt: new Date(),
        };
      } catch (apiError) {
        console.error('BCEL API Error:', apiError.response?.data || apiError.message);
        throw new Error(`BCEL transfer failed: ${apiError.message}`);
      }
    }

    // Mock response ສຳລັບ testing
    return this.mockTransfer('BCEL', accountNumber, amount, reference);
  }

  /**
   * JDB Transfer
   */
  async transferJDB(accountNumber, accountName, amount, reference) {
    if (this.jdbConfig.apiKey && this.jdbConfig.baseURL) {
      // TODO: Implement JDB API
    }
    return this.mockTransfer('JDB', accountNumber, amount, reference);
  }

  /**
   * LDB Transfer
   */
  async transferLDB(accountNumber, accountName, amount, reference) {
    if (this.ldbConfig.apiKey && this.ldbConfig.baseURL) {
      // TODO: Implement LDB API
    }
    return this.mockTransfer('LDB', accountNumber, amount, reference);
  }

  /**
   * Mock Transfer (ສຳລັບ testing)
   */
  async mockTransfer(bankName, accountNumber, amount, reference) {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 500));

    const refNumber = `${bankName}_${Date.now()}_${Math.random().toString(36).substr(2, 6).toUpperCase()}`;

    console.log(`⚠️ MOCK TRANSFER - No real money transferred`);
    
    return {
      success: true,
      referenceNumber: refNumber,
      bankReference: refNumber,
      transferredAt: new Date(),
      mock: true,
    };
  }

  /**
   * ກວດສອບສະຖານະການໂອນ
   */
  async checkTransferStatus(bankName, referenceNumber) {
    // TODO: Implement status checking per bank
    return {
      status: 'completed',
      referenceNumber,
    };
  }
}

module.exports = new BankTransferService();