/**
 * Pool Wallet Service - Sabaidee Wallet
 * 
 * ========================================
 * PAYMENT FLOW:
 * ========================================
 * 1. User scan QR ຮ້ານຄ້າ
 * 2. ສ້າງ Invoice ຈາກ Admin Pool (LNBits)
 * 3. User ຈ່າຍ Sats → Admin Pool ເກັບໄວ້
 * 4. ກວດ Sats ເຂົ້າແລ້ວ? 
 *    - ✅ ເຂົ້າແລ້ວ → Sabaidee Wallet ຈ່າຍ LAK ໃຫ້ຮ້ານຄ້າ
 *    - ❌ ບໍ່ເຂົ້າ → ບໍ່ສັ່ງຈ່າຍ
 * ========================================
 */

const lnbitsService = require('./lnbitsService');
const bankTransferService = require('./bankTransferService');
const PoolWallet = require('../models/Poolwallet');
const Merchant = require('../models/Merchant');
const MerchantPayment = require('../models/MerchantPayment');
const Transaction = require('../models/Transaction');

const DEFAULT_LAK_RATE = 20.30;

class PoolWalletService {

  /**
   * ດຶງ Pool Wallet (Admin)
   */
  async getPoolWallet() {
    let poolWallet = await PoolWallet.findOne({ isPrimary: true, isActive: true })
      .select('+adminKey +invoiceKey');

    if (!poolWallet) {
      // ຖ້າບໍ່ມີ, ໃຊ້ env variables
      if (process.env.POOL_WALLET_ADMIN_KEY) {
        console.log('⚠️ Using Pool Wallet from ENV');
        return {
          adminKey: process.env.POOL_WALLET_ADMIN_KEY,
          invoiceKey: process.env.POOL_WALLET_INVOICE_KEY,
          walletId: process.env.POOL_WALLET_ID || 'ENV_POOL',
        };
      }
      throw new Error('Pool wallet not configured. Please set POOL_WALLET_ADMIN_KEY in .env');
    }

    return poolWallet;
  }

  /**
   * ດຶງອັດຕາແລກປ່ຽນ
   */
  async getExchangeRate(walletKey) {
    try {
      const details = await lnbitsService.getWalletDetails(walletKey);
      const rate = parseFloat(details.extra?.wallet_fiat_rate);
      if (rate && rate > 0) {
        return rate < 1 ? (1 / rate) : rate;
      }
    } catch (err) {
      console.log('⚠️ Using default rate:', DEFAULT_LAK_RATE);
    }
    return DEFAULT_LAK_RATE;
  }

  /**
   * ========================================
   * STEP 1: ສ້າງ Invoice ສຳລັບຈ່າຍຮ້ານຄ້າ
   * ========================================
   */
  async createMerchantPaymentInvoice({
    userId,
    merchantQrCodeId,
    amountLAK,
    memo,
  }) {
    console.log('\n========================================');
    console.log('🛒 CREATE MERCHANT PAYMENT');
    console.log('========================================');

    // 1. ຫາຮ້ານຄ້າ
    const merchant = await Merchant.findOne({
      qrCodeId: merchantQrCodeId,
      isActive: true,
    });

    if (!merchant) {
      throw new Error('ບໍ່ພົບຮ້ານຄ້າ ຫຼື ຮ້ານຄ້າບໍ່ active');
    }

    console.log(`📍 Merchant: ${merchant.merchantName}`);
    console.log(`💰 Amount: ${amountLAK.toLocaleString()} LAK`);

    // 2. ດຶງ Pool Wallet
    const poolWallet = await this.getPoolWallet();

    // 3. ຄຳນວນ
    const exchangeRate = await this.getExchangeRate(poolWallet.adminKey);
    const amountSats = Math.ceil(amountLAK / exchangeRate);
    const feeAmount = Math.round(amountLAK * (merchant.feePercent / 100));
    const netAmount = amountLAK - feeAmount;

    console.log(`📊 Rate: ${exchangeRate} LAK/sat`);
    console.log(`⚡ Amount: ${amountSats} sats`);
    console.log(`💵 Fee: ${feeAmount} LAK (${merchant.feePercent}%)`);
    console.log(`💵 Net to merchant: ${netAmount} LAK`);

    // 4. ສ້າງ Invoice ຈາກ Admin Pool
    const invoice = await lnbitsService.createInvoice(
      poolWallet.adminKey,
      amountSats,
      memo || `ຈ່າຍ ${merchant.merchantName}`,
      'sat'
    );

    console.log(`📄 Invoice: ${invoice.payment_hash}`);

    // 5. ບັນທຶກ MerchantPayment
    const merchantPayment = await MerchantPayment.create({
      merchant: merchant._id,
      user: userId,
      paymentHash: invoice.payment_hash,
      amountSats,
      amountLAK,
      exchangeRate,
      feePercent: merchant.feePercent,
      feeLAK: feeAmount,
      netAmountLAK: netAmount,
      status: 'pending',
      memo,
      bankTransfer: {
        bankName: merchant.bankInfo.bankName,
        accountNumber: merchant.bankInfo.accountNumber,
        accountName: merchant.bankInfo.accountName,
      },
    });

    console.log(`✅ MerchantPayment created: ${merchantPayment._id}`);

    return {
      success: true,
      invoice: {
        paymentRequest: invoice.payment_request,
        paymentHash: invoice.payment_hash,
      },
      merchantPaymentId: merchantPayment._id,
      amounts: {
        amountLAK,
        amountSats,
        feeLAK: feeAmount,
        netAmountLAK: netAmount,
        exchangeRate,
      },
      merchant: {
        id: merchant.merchantId,
        name: merchant.merchantName,
      },
    };
  }

  /**
   * ========================================
   * STEP 2: ກວດ Sats ເຂົ້າ ແລະ ສັ່ງຈ່າຍ LAK
   * ========================================
   * 
   * ⚠️ IMPORTANT:
   * - ຖ້າ Sats ເຂົ້າ Admin Pool ແລ້ວ → ຈ່າຍ LAK
   * - ຖ້າ Sats ບໍ່ເຂົ້າ → ບໍ່ຈ່າຍ
   */
  async checkAndProcessPayment(paymentHash) {
    console.log('\n========================================');
    console.log('🔍 CHECK PAYMENT STATUS');
    console.log(`Payment Hash: ${paymentHash}`);
    console.log('========================================');

    // 1. ດຶງ MerchantPayment
    const merchantPayment = await MerchantPayment.findOne({ paymentHash })
      .populate('merchant');

    if (!merchantPayment) {
      throw new Error('ບໍ່ພົບຂໍ້ມູນການຈ່າຍເງິນ');
    }

    // ຖ້າ completed ແລ້ວ, return
    if (merchantPayment.status === 'completed') {
      return {
        success: true,
        status: 'already_completed',
        merchantPayment,
      };
    }

    // 2. ດຶງ Pool Wallet ແລະ ກວດ payment
    const poolWallet = await this.getPoolWallet();
    const payment = await lnbitsService.checkPayment(poolWallet.adminKey, paymentHash);

    // 3. ກວດວ່າ Sats ເຂົ້າແລ້ວບໍ
    if (!payment.paid) {
      console.log('⏳ Sats NOT received yet');
      console.log('❌ Will NOT trigger LAK payout');
      
      return {
        success: false,
        status: 'pending',
        message: 'ລໍຖ້າການຈ່າຍ Sats',
      };
    }

    // ✅ Sats ເຂົ້າແລ້ວ!
    console.log('✅ SATS RECEIVED in Admin Pool!');
    console.log(`💰 Amount: ${merchantPayment.amountSats} sats`);

    // ອັບເດດສະຖານະ
    merchantPayment.status = 'sats_received';
    merchantPayment.satsReceivedAt = new Date();
    await merchantPayment.save();

    // 4. ສັ່ງ Sabaidee Wallet ຈ່າຍ LAK ໃຫ້ຮ້ານຄ້າ
    console.log('\n🏦 TRIGGERING LAK PAYOUT');
    console.log(`📍 From: Sabaidee Wallet (Company)`);
    console.log(`📍 To: ${merchantPayment.merchant.merchantName}`);
    console.log(`💰 Amount: ${merchantPayment.netAmountLAK.toLocaleString()} LAK`);

    try {
      merchantPayment.status = 'processing';
      await merchantPayment.save();

      const reference = `SW_${merchantPayment._id}`;

      // 5. ໂອນ LAK
      const bankResult = await bankTransferService.transfer(
        merchantPayment.bankTransfer.bankName,
        merchantPayment.bankTransfer.accountNumber,
        merchantPayment.bankTransfer.accountName,
        merchantPayment.netAmountLAK,
        reference
      );

      // 6. ອັບເດດ success
      merchantPayment.status = 'completed';
      merchantPayment.completedAt = new Date();
      merchantPayment.bankTransfer.referenceNumber = bankResult.referenceNumber;
      merchantPayment.bankTransfer.transferredAt = bankResult.transferredAt;
      merchantPayment.bankTransfer.paidBy = 'SABAIDEE_WALLET';
      await merchantPayment.save();

      // 7. ອັບເດດສະຖິຕິຮ້ານຄ້າ
      await Merchant.findByIdAndUpdate(merchantPayment.merchant._id, {
        $inc: {
          totalTransactions: 1,
          totalAmountLAK: merchantPayment.amountLAK,
          totalAmountSats: merchantPayment.amountSats,
        },
      });

      // 8. ອັບເດດ Pool Wallet stats
      if (poolWallet._id) {
        await PoolWallet.findByIdAndUpdate(poolWallet._id, {
          $inc: {
            totalSatsReceived: merchantPayment.amountSats,
            totalLakPaidOut: merchantPayment.netAmountLAK,
            totalFeeCollected: merchantPayment.feeLAK,
            totalTransactions: 1,
          },
        });
      }

      console.log('\n========================================');
      console.log('✅ PAYMENT COMPLETED');
      console.log('   Sats → Admin Pool (stored)');
      console.log('   LAK → Merchant (paid by Sabaidee Wallet)');
      console.log('========================================\n');

      return {
        success: true,
        status: 'completed',
        flow: {
          satsReceivedBy: 'Admin Pool (LNBits)',
          lakPaidBy: 'Sabaidee Wallet',
          lakPaidTo: merchantPayment.merchant.merchantName,
        },
        payment: {
          amountSats: merchantPayment.amountSats,
          amountLAK: merchantPayment.amountLAK,
          netAmountLAK: merchantPayment.netAmountLAK,
          feeLAK: merchantPayment.feeLAK,
          bankReference: bankResult.referenceNumber,
        },
      };

    } catch (bankError) {
      console.error('❌ LAK payout failed:', bankError.message);

      merchantPayment.status = 'failed';
      merchantPayment.errorMessage = bankError.message;
      merchantPayment.retryCount += 1;
      await merchantPayment.save();

      return {
        success: false,
        status: 'lak_payout_failed',
        satsReceived: true,
        error: bankError.message,
      };
    }
  }

  /**
   * ດຶງຍອດເງິນ Pool Wallet
   */
  async getPoolBalance() {
    const poolWallet = await this.getPoolWallet();
    const balance = await lnbitsService.getWalletBalance(poolWallet.adminKey);
    const exchangeRate = await this.getExchangeRate(poolWallet.adminKey);

    return {
      balanceMsats: balance,
      balanceSats: balance / 1000,
      balanceLAK: Math.round((balance / 1000) * exchangeRate),
      exchangeRate,
    };
  }

  /**
   * ສ້າງ Pool Wallet ໃໝ່ (Admin only)
   */
  async createPoolWallet(walletName = 'SABAIDEE_ADMIN_POOL') {
    const existing = await PoolWallet.findOne({ isPrimary: true });
    if (existing) {
      throw new Error('Primary pool wallet already exists');
    }

    const walletData = await lnbitsService.createWallet(walletName);

    const poolWallet = await PoolWallet.create({
      walletId: walletData.walletId,
      walletName: walletData.walletName,
      adminKey: walletData.adminKey,
      invoiceKey: walletData.invoiceKey,
      isPrimary: true,
    });

    return {
      walletId: poolWallet.walletId,
      walletName: poolWallet.walletName,
      message: 'Pool wallet created. Save the admin key securely!',
    };
  }

  /**
   * Retry failed payment
   */
  async retryFailedPayment(merchantPaymentId) {
    const mp = await MerchantPayment.findById(merchantPaymentId).populate('merchant');
    
    if (!mp) throw new Error('Payment not found');
    if (mp.status !== 'failed') throw new Error('Payment is not in failed status');
    if (mp.retryCount >= 3) throw new Error('Max retry attempts reached');

    return this.checkAndProcessPayment(mp.paymentHash);
  }
}

module.exports = new PoolWalletService();