const axios = require('axios');

class LNbitsService {
  constructor() {
    this.baseURL = process.env.LNBITS_URL;
    this.adminKey = process.env.LNBITS_ADMIN_KEY;
    this.adminUserId = process.env.LNBITS_ADMIN_USER_ID;
  }

  /**
   * Create a new wallet in LNbits (ພາຍໃຕ້ admin user - ສະແດງໃນ dashboard)
   */
  async createWallet(walletName) {
    try {
      const response = await axios.post(
        `${this.baseURL}/api/v1/wallet?usr=${this.adminUserId}`,
        { name: walletName },
        {
          headers: {
            'X-Api-Key': this.adminKey,
            'Content-Type': 'application/json',
          },
        }
      );

      console.log('✅ LNbits Wallet Created:', response.data.name);

      return {
        walletId: response.data.id,
        walletName: response.data.name,
        adminKey: response.data.adminkey,
        invoiceKey: response.data.inkey,
      };
    } catch (error) {
      console.error('LNbits Create Wallet Error:', error.response?.data || error.message);
      throw new Error('Failed to create LNbits wallet');
    }
  }

  /**
   * Get wallet balance
   */
  async getWalletBalance(walletKey) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/wallet`,
        {
          headers: { 'X-Api-Key': walletKey },
        }
      );
      return response.data.balance;
    } catch (error) {
      console.error('LNbits Get Balance Error:', error.response?.data || error.message);
      return 0;
    }
  }

  /**
   * Get wallet details
   */
  async getWalletDetails(walletKey) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/wallet`,
        {
          headers: { 'X-Api-Key': walletKey },
        }
      );
      return response.data;
    } catch (error) {
      console.error('LNbits Get Wallet Details Error:', error.response?.data || error.message);
      throw new Error('Failed to get wallet details');
    }
  }

  /**
   * Create Lightning invoice
   */
  async createInvoice(walletKey, amount, memo = 'Sabaidee Wallet Payment', unit = 'sat') {
    try {
      console.log('📤 LNbits Create Invoice:', { amount, memo, unit });

      const response = await axios.post(
        `${this.baseURL}/api/v1/payments`,
        {
          out: false,
          amount: amount,
          memo: memo,
          unit: unit,
        },
        {
          headers: {
            'X-Api-Key': walletKey,
            'Content-Type': 'application/json',
          },
        }
      );

      console.log('📥 Invoice created:', response.data.payment_hash);
      return response.data;
    } catch (error) {
      console.error('❌ LNbits Create Invoice Error:', error.response?.data || error.message);
      throw new Error('Failed to create invoice');
    }
  }

  /**
   * Pay a Lightning invoice
   */
  async payInvoice(walletKey, bolt11) {
    try {
      console.log('📤 LNbits Pay Invoice...');
      console.log(`   Invoice: ${bolt11.substring(0, 50)}...`);

      const response = await axios.post(
        `${this.baseURL}/api/v1/payments`,
        {
          out: true,
          bolt11: bolt11,
        },
        {
          headers: {
            'X-Api-Key': walletKey,
            'Content-Type': 'application/json',
          },
          timeout: 60000,
        }
      );

      console.log('✅ Payment successful:', response.data.payment_hash);
      return response.data;

    } catch (error) {
      const lnbitsError = error.response?.data;
      let errorMessage = 'Failed to pay invoice';

      if (lnbitsError) {
        console.error('❌ LNbits Pay Error:', JSON.stringify(lnbitsError, null, 2));
        
        if (typeof lnbitsError === 'string') {
          errorMessage = lnbitsError;
        } else if (lnbitsError.detail) {
          errorMessage = lnbitsError.detail;
        } else if (lnbitsError.message) {
          errorMessage = lnbitsError.message;
        }

        // ແປ error ເປັນພາສາລາວ
        if (errorMessage.includes('insufficient balance') || errorMessage.includes('Insufficient')) {
          errorMessage = 'ຍອດເງິນບໍ່ພຽງພໍ';
        } else if (errorMessage.includes('expired') || errorMessage.includes('Expired')) {
          errorMessage = 'Invoice ໝົດອາຍຸແລ້ວ';
        } else if (errorMessage.includes('already paid') || errorMessage.includes('Already paid')) {
          errorMessage = 'Invoice ນີ້ຖືກຈ່າຍແລ້ວ';
        } else if (errorMessage.includes('route') || errorMessage.includes('Route')) {
          errorMessage = 'ບໍ່ພົບເສັ້ນທາງການຈ່າຍເງິນ';
        } else if (errorMessage.includes('invalid') || errorMessage.includes('Invalid')) {
          errorMessage = 'Invoice ບໍ່ຖືກຕ້ອງ';
        } else if (errorMessage.includes('self-payment') || errorMessage.includes('own invoice')) {
          errorMessage = 'ບໍ່ສາມາດຈ່າຍໃຫ້ຕົນເອງໄດ້';
        }
      } else {
        console.error('❌ LNbits Pay Error:', error.message);
        
        if (error.code === 'ECONNABORTED' || error.message.includes('timeout')) {
          errorMessage = 'ການເຊື່ອມຕໍ່ໝົດເວລາ';
        }
      }

      const customError = new Error(errorMessage);
      customError.lnbitsError = lnbitsError;
      throw customError;
    }
  }

  /**
   * Get payment history
   */
  async getPayments(walletKey) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/payments`,
        {
          headers: { 'X-Api-Key': walletKey },
        }
      );
      return response.data;
    } catch (error) {
      console.error('LNbits Get Payments Error:', error.response?.data || error.message);
      return [];
    }
  }

  /**
   * Check if a payment is complete
   */
  async checkPayment(walletKey, paymentHash) {
    try {
      const response = await axios.get(
        `${this.baseURL}/api/v1/payments/${paymentHash}`,
        {
          headers: { 'X-Api-Key': walletKey },
        }
      );
      return response.data;
    } catch (error) {
      console.error('LNbits Check Payment Error:', error.response?.data || error.message);
      throw new Error('Failed to check payment');
    }
  }

  /**
   * Decode Lightning invoice
   */
  async decodeInvoice(walletKey, bolt11) {
    try {
      const response = await axios.post(
        `${this.baseURL}/api/v1/payments/decode`,
        { data: bolt11 },
        {
          headers: {
            'X-Api-Key': walletKey,
            'Content-Type': 'application/json',
          },
        }
      );
      return response.data;
    } catch (error) {
      console.error('LNbits Decode Error:', error.response?.data || error.message);
      return null;
    }
  }
}

module.exports = new LNbitsService();