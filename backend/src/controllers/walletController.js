const lnbitsService = require('../services/lnbitsService');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
const Transaction = require('../models/Transaction');

// ✅ Default exchange rate
const DEFAULT_LAK_RATE = 20.30;

/**
 * @desc    Get wallet balance
 * @route   GET /api/wallet/balance
 * @access  Private
 */
exports.getBalance = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey +invoiceKey');

    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'No wallet found for this user',
      });
    }

    const balance = await lnbitsService.getWalletBalance(wallet.adminKey);

    wallet.balance = balance;
    await wallet.save();

    res.status(200).json({
      success: true,
      data: {
        balance,
        walletId: wallet.walletId,
        walletName: wallet.walletName,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Create Lightning invoice
 * @route   POST /api/wallet/invoice
 * @access  Private
 */
exports.createInvoice = async (req, res, next) => {
  try {
    let { amount, memo } = req.body;

    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey +invoiceKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    const walletDetails = await lnbitsService.getWalletDetails(wallet.adminKey);
    let exchangeRate = parseFloat(walletDetails.extra?.wallet_fiat_rate);

    if (!exchangeRate || exchangeRate <= 0) {
      exchangeRate = DEFAULT_LAK_RATE;
    }

    const amountSats = Math.ceil(amount / exchangeRate);

    const invoice = await lnbitsService.createInvoice(
      wallet.adminKey,
      amountSats,
      memo || 'Sabaidee Wallet Payment',
      'sat'
    );

    const transaction = await Transaction.create({
      user: req.user._id,
      wallet: wallet._id,
      paymentHash: invoice.payment_hash,
      type: 'receive',
      amountLAK: amount,
      amountSats: amountSats,
      status: 'pending',
      memo: memo || 'Sabaidee Wallet Payment',
      bolt11: invoice.payment_request,
      exchangeRate: exchangeRate,
    });

    res.status(201).json({
      success: true,
      message: 'Invoice created successfully',
      data: {
        ...invoice,
        transactionId: transaction._id,
        amountSats: amountSats,
        amountLAK: amount,
        exchangeRate: exchangeRate,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Pay Lightning invoice
 * @route   POST /api/wallet/pay
 * @access  Private
 */
exports.payInvoice = async (req, res, next) => {
  try {
    const { bolt11 } = req.body;

    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({
        success: false,
        message: 'No wallet found for this user',
      });
    }

    const payment = await lnbitsService.payInvoice(wallet.adminKey, bolt11);

    let exchangeRate = DEFAULT_LAK_RATE;
    try {
      const walletDetails = await lnbitsService.getWalletDetails(wallet.adminKey);
      const fiatRate = parseFloat(walletDetails.extra?.wallet_fiat_rate);
      if (fiatRate && fiatRate > 0) {
        exchangeRate = fiatRate;
      }
    } catch (err) {
      console.log('⚠️ Using default rate for payment');
    }

    const amountSats = Math.abs(payment.amount) / 1000;
    const amountLAK = Math.round(amountSats * exchangeRate);

    const transaction = await Transaction.create({
      user: req.user._id,
      wallet: wallet._id,
      paymentHash: payment.payment_hash,
      type: 'send',
      amountLAK: amountLAK,
      amountSats: amountSats,
      status: 'completed',
      memo: payment.memo || 'Lightning Payment',
      bolt11: bolt11,
      exchangeRate: exchangeRate,
      completedAt: new Date(),
    });

    const newBalance = await lnbitsService.getWalletBalance(wallet.adminKey);
    wallet.balance = newBalance;
    await wallet.save();

    res.status(200).json({
      success: true,
      message: 'Payment sent successfully',
      data: {
        paymentHash: payment.payment_hash,
        amountSats: amountSats,
        amountLAK: amountLAK,
        transactionId: transaction._id,
        newBalance: newBalance,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * ✅ Send Payment - ຮອງຮັບ EMV QR, Merchant, Lightning, Wallet
 * @route   POST /api/wallet/send
 * @access  Private
 * 
 * FLOW ສຳລັບ EMV QR / Merchant:
 * User Wallet → (Sats) → Admin Pool (LNBits) → ເກັບໄວ້
 * Bank Transfer → DEMO (ບໍ່ໂອນຈິງ - ລໍຖ້າ Bank API)
 */
exports.sendPayment = async (req, res, next) => {
  try {
    const { toWalletId, amount, description } = req.body;

    console.log('\n========================================');
    console.log('💸 SEND PAYMENT REQUEST');
    console.log(`To: ${toWalletId}`);
    console.log(`Amount: ${amount} LAK`);
    console.log('========================================');

    // Validate
    if (!toWalletId || !amount) {
      return res.status(400).json({
        success: false,
        message: 'ກະລຸນາປ້ອນ Wallet ID ແລະ ຈຳນວນເງິນ',
      });
    }

    // ດຶງ sender wallet
    const senderWallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!senderWallet) {
      return res.status(404).json({
        success: false,
        message: 'ບໍ່ພົບ wallet ຂອງທ່ານ',
      });
    }

    // ດຶງອັດຕາແລກປ່ຽນ
    let exchangeRate = DEFAULT_LAK_RATE;
    try {
      const walletDetails = await lnbitsService.getWalletDetails(senderWallet.adminKey);
      const fiatRate = parseFloat(walletDetails.extra?.wallet_fiat_rate);
      if (fiatRate && fiatRate > 0) {
        exchangeRate = fiatRate < 1 ? (1 / fiatRate) : fiatRate;
      }
    } catch (err) {
      console.log('⚠️ Using default rate');
    }

    const amountSats = Math.ceil(amount / exchangeRate);
    console.log(`📊 Rate: ${exchangeRate} LAK/sat`);
    console.log(`⚡ Amount: ${amountSats} sats`);

    // ກວດ balance
    const currentBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
    const currentBalanceSats = currentBalance / 1000;

    if (currentBalanceSats < amountSats) {
      return res.status(400).json({
        success: false,
        message: `ຍອດເງິນບໍ່ພຽງພໍ. ມີ ${Math.floor(currentBalanceSats * exchangeRate).toLocaleString()} LAK`,
      });
    }

    // ========================================
    // ກວດປະເພດ QR/ID
    // ========================================
    const EMVQRParser = require('../utils/emvQRParser');
    const qrType = EMVQRParser.detectType(toWalletId);
    console.log(`📋 Detected type: ${qrType}`);

    // ========================================
    // 1. EMV QR (ທະນາຄານ) - DEMO MODE
    // ========================================
    if (qrType === 'emv_qr') {
      console.log('🏦 Processing EMV QR (Bank QR) - DEMO MODE');
      
      const emvData = EMVQRParser.parse(toWalletId);
      console.log('EMV Data:', JSON.stringify(emvData.data, null, 2));

      // ດຶງ Admin Pool Wallet
      const adminKey = process.env.POOL_WALLET_ADMIN_KEY;
      if (!adminKey) {
        return res.status(500).json({
          success: false,
          message: 'Admin Pool Wallet ບໍ່ໄດ້ຕັ້ງຄ່າ. ກະລຸນາຕັ້ງ POOL_WALLET_ADMIN_KEY ໃນ .env',
        });
      }

      // ສ້າງ invoice ຈາກ Admin Pool
      const invoice = await lnbitsService.createInvoice(
        adminKey,
        amountSats,
        `EMV Payment: ${emvData.data.merchantName || 'Bank QR'}`,
        'sat'
      );

      // ຈ່າຍ invoice ຈາກ User → Admin Pool
      const payment = await lnbitsService.payInvoice(senderWallet.adminKey, invoice.payment_request);
      console.log('✅ Sats transferred to Admin Pool');

      // ບັນທຶກ Transaction
      await Transaction.create({
        user: req.user._id,
        wallet: senderWallet._id,
        paymentHash: payment.payment_hash,
        type: 'send',
        amountLAK: amount,
        amountSats: amountSats,
        status: 'completed',
        memo: description || `ຈ່າຍ QR ${emvData.data.bank?.bankName || 'Bank'}`,
        exchangeRate: exchangeRate,
        completedAt: new Date(),
        metadata: {
          transferType: 'emv_qr',
          isDemo: true,
          emvData: {
            bank: emvData.data.bank,
            merchantName: emvData.data.merchantName,
            currency: emvData.data.currency,
          },
        },
      });

      // ອັບເດດ balance
      const newBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
      senderWallet.balance = newBalance;
      await senderWallet.save();

      // Generate fake bank reference
      const fakeBankRef = `DEMO_${Date.now()}_${Math.random().toString(36).substr(2, 6).toUpperCase()}`;

      console.log('========================================');
      console.log('✅ PAYMENT COMPLETED (DEMO)');
      console.log(`   Sats: ${amountSats} → Admin Pool ✓`);
      console.log(`   LAK: ${amount} → Bank Transfer (DEMO) ✓`);
      console.log(`   Reference: ${fakeBankRef}`);
      console.log('========================================\n');

      return res.status(200).json({
        success: true,
        message: 'ການຈ່າຍເງິນສຳເລັດ',
        data: {
          type: 'emv_qr_payment',
          mode: 'DEMO',
          paymentHash: payment.payment_hash,
          amountLAK: amount,
          amountSats: amountSats,
          bankTransfer: {
            status: 'DEMO_COMPLETED',
            reference: fakeBankRef,
            bank: emvData.data.bank?.bankName || 'Unknown Bank',
            merchantName: emvData.data.merchantName || 'Merchant',
            note: '⚠️ DEMO: Sats ເກັບໄວ້ໃນ Admin Pool. Bank Transfer ຍັງບໍ່ໂອນຈິງ.',
          },
          newBalanceLAK: Math.floor((newBalance / 1000) * exchangeRate),
        },
      });
    }

    // ========================================
    // 2. Sabaidee Merchant QR - DEMO MODE
    // ========================================
    if (qrType === 'sabaidee_merchant') {
      console.log('🏪 Processing Sabaidee Merchant - DEMO MODE');

      // ດຶງ Admin Pool Wallet
      const adminKey = process.env.POOL_WALLET_ADMIN_KEY;
      if (!adminKey) {
        return res.status(500).json({
          success: false,
          message: 'Admin Pool Wallet ບໍ່ໄດ້ຕັ້ງຄ່າ',
        });
      }

      // ຫາຂໍ້ມູນ Merchant (ຖ້າມີ)
      let merchantName = 'Merchant';
      let merchantInfo = null;
      try {
        const Merchant = require('../models/Merchant');
        const merchant = await Merchant.findOne({
          $or: [{ qrCodeId: toWalletId }, { merchantId: toWalletId }],
          isActive: true,
        });
        if (merchant) {
          merchantName = merchant.merchantName;
          merchantInfo = {
            id: merchant.merchantId,
            name: merchant.merchantName,
            bank: merchant.bankInfo?.bankName,
          };
        }
      } catch (e) {
        console.log('Merchant model not found, using default');
      }

      // ສ້າງ invoice ຈາກ Admin Pool
      const invoice = await lnbitsService.createInvoice(
        adminKey,
        amountSats,
        `Merchant Payment: ${merchantName}`,
        'sat'
      );

      // ຈ່າຍ invoice ຈາກ User → Admin Pool
      const payment = await lnbitsService.payInvoice(senderWallet.adminKey, invoice.payment_request);
      console.log('✅ Sats transferred to Admin Pool');

      // ບັນທຶກ Transaction
      await Transaction.create({
        user: req.user._id,
        wallet: senderWallet._id,
        paymentHash: payment.payment_hash,
        type: 'send',
        amountLAK: amount,
        amountSats: amountSats,
        status: 'completed',
        memo: description || `ຈ່າຍ ${merchantName}`,
        exchangeRate: exchangeRate,
        completedAt: new Date(),
        metadata: {
          transferType: 'merchant',
          isDemo: true,
          merchant: merchantInfo,
        },
      });

      // ອັບເດດ balance
      const newBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
      senderWallet.balance = newBalance;
      await senderWallet.save();

      const fakeBankRef = `DEMO_MER_${Date.now()}`;

      return res.status(200).json({
        success: true,
        message: `ຈ່າຍໃຫ້ ${merchantName} ສຳເລັດ`,
        data: {
          type: 'merchant_payment',
          mode: 'DEMO',
          paymentHash: payment.payment_hash,
          amountLAK: amount,
          amountSats: amountSats,
          merchant: merchantInfo,
          bankTransfer: {
            status: 'DEMO_COMPLETED',
            reference: fakeBankRef,
            note: '⚠️ DEMO: Sats ເກັບໄວ້ໃນ Admin Pool.',
          },
          newBalanceLAK: Math.floor((newBalance / 1000) * exchangeRate),
        },
      });
    }

    // ========================================
    // 3. Lightning Invoice - ຕັດເງິນເຂົ້າ Admin Pool
    // ========================================
    if (qrType === 'lightning_invoice') {
      console.log('⚡ Processing Lightning Invoice → Admin Pool');
      
      // ເອົາ prefix "lightning:" ອອກ
      const cleanInvoice = EMVQRParser.cleanLightningInvoice(toWalletId);
      console.log(`📝 Clean invoice: ${cleanInvoice.substring(0, 50)}...`);

      // ດຶງ Admin Pool Wallet
      const adminKey = process.env.POOL_WALLET_ADMIN_KEY;
      if (!adminKey) {
        return res.status(500).json({
          success: false,
          message: 'Admin Pool Wallet ບໍ່ໄດ້ຕັ້ງຄ່າ',
        });
      }

      try {
        // Decode invoice ເພື່ອເບິ່ງຈຳນວນເງິນ
        let invoiceAmountSats = amountSats;
        let invoiceMemo = 'Lightning Payment';
        
        const decoded = await lnbitsService.decodeInvoice(senderWallet.adminKey, cleanInvoice);
        if (decoded) {
          invoiceAmountSats = Math.ceil(decoded.amount_msat / 1000);
          invoiceMemo = decoded.description || 'Lightning Payment';
          console.log(`📋 Invoice amount: ${invoiceAmountSats} sats`);
          console.log(`📋 Invoice memo: ${invoiceMemo}`);
          
          // ກວດວ່າ expired ບໍ
          if (decoded.expiry && decoded.date) {
            const expireTime = (decoded.date + decoded.expiry) * 1000;
            if (Date.now() > expireTime) {
              return res.status(400).json({
                success: false,
                message: 'Invoice ໝົດອາຍຸແລ້ວ. ກະລຸນາຂໍ Invoice ໃໝ່.',
              });
            }
          }
        }

        // ສ້າງ invoice ຈາກ Admin Pool (ແທນທີ່ຈະຈ່າຍ invoice ຕົ້ນສະບັບ)
        const poolInvoice = await lnbitsService.createInvoice(
          adminKey,
          invoiceAmountSats,
          `LN Payment: ${invoiceMemo}`,
          'sat'
        );

        // ຈ່າຍຈາກ User → Admin Pool
        const payment = await lnbitsService.payInvoice(senderWallet.adminKey, poolInvoice.payment_request);
        console.log('✅ Sats transferred to Admin Pool');

        const paidSats = invoiceAmountSats;
        const paidLAK = Math.round(paidSats * exchangeRate);

        // ບັນທຶກ Transaction
        await Transaction.create({
          user: req.user._id,
          wallet: senderWallet._id,
          paymentHash: payment.payment_hash,
          type: 'send',
          amountLAK: paidLAK,
          amountSats: paidSats,
          status: 'completed',
          memo: description || invoiceMemo,
          bolt11: cleanInvoice,
          exchangeRate: exchangeRate,
          completedAt: new Date(),
          metadata: {
            transferType: 'lightning_to_pool',
            originalInvoice: cleanInvoice.substring(0, 50),
            isDemo: true,
          },
        });

        const newBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
        senderWallet.balance = newBalance;
        await senderWallet.save();

        // Generate reference
        const paymentRef = `LN_${Date.now()}_${Math.random().toString(36).substr(2, 6).toUpperCase()}`;

        console.log('========================================');
        console.log('✅ LIGHTNING PAYMENT TO POOL COMPLETED');
        console.log(`   Sats: ${paidSats} → Admin Pool ✓`);
        console.log(`   Reference: ${paymentRef}`);
        console.log('========================================\n');

        return res.status(200).json({
          success: true,
          message: 'ຈ່າຍ Lightning Invoice ສຳເລັດ',
          data: {
            type: 'lightning_invoice',
            mode: 'POOL',
            paymentHash: payment.payment_hash,
            amountSats: paidSats,
            amountLAK: paidLAK,
            reference: paymentRef,
            note: 'Sats ເກັບໄວ້ໃນ Admin Pool',
            newBalanceLAK: Math.floor((newBalance / 1000) * exchangeRate),
          },
        });

      } catch (payError) {
        console.error('❌ Lightning payment failed:', payError.message);
        
        return res.status(400).json({
          success: false,
          message: payError.message || 'ການຈ່າຍ Lightning Invoice ລົ້ມເຫລວ',
        });
      }
    }

    // ========================================
    // 4. Internal Wallet Transfer - ຈ່າຍຈິງ
    // ========================================
    console.log('👤 Checking for internal wallet...');
    
    const recipientWallet = await Wallet.findOne({
      $or: [
        { walletId: toWalletId },
        { invoiceKey: toWalletId },
      ],
      isActive: true,
    }).select('+adminKey +invoiceKey');

    if (!recipientWallet) {
      // ບໍ່ພົບ - ສົ່ງໄປ Admin Pool ເປັນ demo
      console.log('⚠️ Unknown ID type, sending to Admin Pool as demo');
      
      const adminKey = process.env.POOL_WALLET_ADMIN_KEY;
      if (adminKey) {
        const invoice = await lnbitsService.createInvoice(
          adminKey,
          amountSats,
          `QR Payment`,
          'sat'
        );

        const payment = await lnbitsService.payInvoice(senderWallet.adminKey, invoice.payment_request);

        await Transaction.create({
          user: req.user._id,
          wallet: senderWallet._id,
          paymentHash: payment.payment_hash,
          type: 'send',
          amountLAK: amount,
          amountSats: amountSats,
          status: 'completed',
          memo: description || 'QR Payment',
          exchangeRate: exchangeRate,
          completedAt: new Date(),
          metadata: { transferType: 'unknown_qr', isDemo: true },
        });

        const newBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
        senderWallet.balance = newBalance;
        await senderWallet.save();

        return res.status(200).json({
          success: true,
          message: 'ການຈ່າຍເງິນສຳເລັດ',
          data: {
            type: 'qr_payment',
            mode: 'DEMO',
            paymentHash: payment.payment_hash,
            amountLAK: amount,
            amountSats: amountSats,
            note: '⚠️ DEMO: Sats ເກັບໄວ້ໃນ Admin Pool.',
            newBalanceLAK: Math.floor((newBalance / 1000) * exchangeRate),
          },
        });
      }

      return res.status(404).json({
        success: false,
        message: 'ບໍ່ພົບ Wallet ID ນີ້',
      });
    }

    // Internal Transfer
    console.log(`👤 Internal transfer to wallet: ${recipientWallet.walletId}`);

    const invoice = await lnbitsService.createInvoice(
      recipientWallet.adminKey,
      amountSats,
      description || 'Internal Transfer',
      'sat'
    );

    const payment = await lnbitsService.payInvoice(senderWallet.adminKey, invoice.payment_request);
    console.log('✅ Internal transfer completed');

    // ບັນທຶກ transaction ຂອງ sender
    await Transaction.create({
      user: req.user._id,
      wallet: senderWallet._id,
      paymentHash: payment.payment_hash,
      type: 'send',
      amountLAK: amount,
      amountSats: amountSats,
      status: 'completed',
      memo: description || 'Internal Transfer',
      bolt11: invoice.payment_request,
      exchangeRate: exchangeRate,
      completedAt: new Date(),
      metadata: { transferType: 'internal', toWalletId: recipientWallet.walletId },
    });

    // ບັນທຶກ transaction ຂອງ recipient
    const recipientUser = await Wallet.findById(recipientWallet._id).select('user');
    if (recipientUser) {
      await Transaction.create({
        user: recipientUser.user,
        wallet: recipientWallet._id,
        paymentHash: payment.payment_hash,
        type: 'receive',
        amountLAK: amount,
        amountSats: amountSats,
        status: 'completed',
        memo: description || 'Internal Transfer',
        bolt11: invoice.payment_request,
        exchangeRate: exchangeRate,
        completedAt: new Date(),
        metadata: { transferType: 'internal', fromUserId: req.user._id },
      });
    }

    const newBalance = await lnbitsService.getWalletBalance(senderWallet.adminKey);
    senderWallet.balance = newBalance;
    await senderWallet.save();

    res.status(200).json({
      success: true,
      message: 'ໂອນເງິນສຳເລັດ',
      data: {
        type: 'internal_transfer',
        paymentHash: payment.payment_hash,
        amountLAK: amount,
        amountSats: amountSats,
        toWalletId: recipientWallet.walletId,
        newBalanceLAK: Math.floor((newBalance / 1000) * exchangeRate),
      },
    });

  } catch (error) {
    console.error('❌ Send payment error:', error);
    next(error);
  }
};

/**
 * @desc    Get payment history
 */
exports.getPayments = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    const payments = await lnbitsService.getPayments(wallet.adminKey);

    res.status(200).json({
      success: true,
      data: { payments, count: payments.length },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Check payment status
 */
exports.checkPayment = async (req, res, next) => {
  try {
    const { paymentHash } = req.params;

    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    const payment = await lnbitsService.checkPayment(wallet.adminKey, paymentHash);

    if (payment.paid) {
      const amountMsats = payment.details?.amount || payment.amount || 0;
      const amountSats = Math.abs(amountMsats) / 1000;
      const amountLAK = payment.details?.extra?.wallet_fiat_amount || Math.round(amountSats * DEFAULT_LAK_RATE);

      let transaction = await Transaction.findOne({ paymentHash });

      if (transaction) {
        transaction.status = 'completed';
        transaction.completedAt = new Date();
        if (amountSats > 0) transaction.amountSats = amountSats;
        if (amountLAK > 0) transaction.amountLAK = amountLAK;
        await transaction.save();
      }

      const newBalance = await lnbitsService.getWalletBalance(wallet.adminKey);
      wallet.balance = newBalance;
      await wallet.save();
    }

    res.status(200).json({ success: true, data: payment });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get wallet details
 */
exports.getWalletDetails = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    const details = await lnbitsService.getWalletDetails(wallet.adminKey);

    res.status(200).json({ success: true, data: details });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Create wallet manually
 */
exports.createWallet = async (req, res, next) => {
  try {
    const user = await User.findById(req.user._id);

    const existingWallet = await Wallet.findOne({ user: req.user._id, isDefault: true });
    
    if (existingWallet) {
      return res.status(400).json({
        success: false,
        message: 'Default wallet already exists',
      });
    }

    const walletName = `${user.fullName.replace(/\s+/g, '_')}_wallet`;
    const walletData = await lnbitsService.createWallet(walletName);

    const wallet = await Wallet.create({
      user: req.user._id,
      walletId: walletData.walletId,
      walletName: walletData.walletName,
      adminKey: walletData.adminKey,
      invoiceKey: walletData.invoiceKey,
      balance: 0,
      isDefault: true,
    });

    res.status(201).json({
      success: true,
      message: 'Wallet created successfully',
      data: { walletId: wallet.walletId, walletName: wallet.walletName },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get all wallets for user
 */
exports.getWallets = async (req, res, next) => {
  try {
    const wallets = await Wallet.find({ user: req.user._id, isActive: true });

    res.status(200).json({
      success: true,
      data: { wallets, count: wallets.length },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get transaction history
 */
exports.getTransactions = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, type, status } = req.query;

    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    // Auto-sync from LNBits
    try {
      const payments = await lnbitsService.getPayments(wallet.adminKey);
      
      for (const payment of payments) {
        const exists = await Transaction.findOne({ paymentHash: payment.payment_hash });

        if (!exists) {
          const amountSats = Math.abs(payment.amount || 0) / 1000;
          const amountLAK = payment.extra?.wallet_fiat_amount || Math.round(amountSats * DEFAULT_LAK_RATE);

          let createdAt = new Date();
          if (payment.time) {
            createdAt = typeof payment.time === 'number' ? new Date(payment.time * 1000) : new Date(payment.time);
          }

          await Transaction.create({
            user: req.user._id,
            wallet: wallet._id,
            paymentHash: payment.payment_hash,
            type: payment.out ? 'send' : 'receive',
            amountSats,
            amountLAK,
            status: payment.pending ? 'pending' : 'completed',
            memo: payment.memo || 'Lightning Payment',
            bolt11: payment.bolt11,
            exchangeRate: DEFAULT_LAK_RATE,
            completedAt: payment.pending ? null : createdAt,
            createdAt,
          });
        }
      }
    } catch (syncError) {
      console.log('⚠️ Auto-sync failed:', syncError.message);
    }

    const query = { user: req.user._id };
    if (type) query.type = type;
    if (status) query.status = status;

    const transactions = await Transaction.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await Transaction.countDocuments(query);

    res.status(200).json({
      success: true,
      data: {
        transactions,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total,
          pages: Math.ceil(total / limit),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get exchange rate
 */
exports.getExchangeRate = async (req, res, next) => {
  try {
    const wallet = await Wallet.findOne({ user: req.user._id, isDefault: true })
      .select('+adminKey');

    if (!wallet) {
      return res.status(404).json({ success: false, message: 'No wallet found' });
    }

    let exchangeRate = DEFAULT_LAK_RATE;

    try {
      const walletDetails = await lnbitsService.getWalletDetails(wallet.adminKey);
      const fiatRate = parseFloat(walletDetails.extra?.wallet_fiat_rate);

      if (fiatRate && fiatRate > 0) {
        exchangeRate = fiatRate < 1 ? (1 / fiatRate) : fiatRate;
      }
    } catch (err) {
      console.log('⚠️ Using default rate');
    }

    res.status(200).json({
      success: true,
      data: { satToLakRate: exchangeRate, currency: 'LAK' },
    });
  } catch (error) {
    next(error);
  }
};