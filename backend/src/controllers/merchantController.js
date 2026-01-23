/**
 * Merchant Controller
 * API handlers ສຳລັບ Merchant Payment System
 */

const poolWalletService = require('../services/poolWalletService');
const Merchant = require('../models/Merchant');
const MerchantPayment = require('../models/MerchantPayment');

// ==================== USER APIs ====================

/**
 * @desc    ດຶງຂໍ້ມູນຮ້ານຄ້າຈາກ QR Code
 * @route   GET /api/merchant/info/:qrCodeId
 * @access  Private
 */
exports.getMerchantByQR = async (req, res, next) => {
  try {
    const { qrCodeId } = req.params;

    const merchant = await Merchant.findOne({
      qrCodeId,
      isActive: true,
    }).select('merchantId merchantName qrCodeId feePercent bankInfo.bankName');

    if (!merchant) {
      return res.status(404).json({
        success: false,
        message: 'ບໍ່ພົບຮ້ານຄ້າ',
      });
    }

    res.status(200).json({
      success: true,
      data: merchant,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ສ້າງການຈ່າຍເງິນໃຫ້ຮ້ານຄ້າ (User scan QR)
 * @route   POST /api/merchant/pay
 * @access  Private
 */
exports.createPayment = async (req, res, next) => {
  try {
    const { qrCodeId, amountLAK, memo } = req.body;

    // Validate
    if (!qrCodeId) {
      return res.status(400).json({
        success: false,
        message: 'ກະລຸນາລະບຸ qrCodeId',
      });
    }

    if (!amountLAK || amountLAK < 1000) {
      return res.status(400).json({
        success: false,
        message: 'ຈຳນວນເງິນຕ້ອງຢ່າງໜ້ອຍ 1,000 ກີບ',
      });
    }

    const result = await poolWalletService.createMerchantPaymentInvoice({
      userId: req.user._id,
      merchantQrCodeId: qrCodeId,
      amountLAK: parseInt(amountLAK),
      memo,
    });

    res.status(201).json({
      success: true,
      message: 'ສ້າງ Invoice ສຳເລັດ - ລໍຖ້າການຈ່າຍ',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ກວດສອບ ແລະ ດຳເນີນການຈ່າຍເງິນ
 * @route   POST /api/merchant/pay/check
 * @access  Private
 */
exports.checkPayment = async (req, res, next) => {
  try {
    const { paymentHash } = req.body;

    if (!paymentHash) {
      return res.status(400).json({
        success: false,
        message: 'ກະລຸນາລະບຸ paymentHash',
      });
    }

    const result = await poolWalletService.checkAndProcessPayment(paymentHash);

    res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ດຶງປະຫວັດການຈ່າຍເງິນຂອງ user
 * @route   GET /api/merchant/history
 * @access  Private
 */
exports.getPaymentHistory = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, status } = req.query;

    const query = { user: req.user._id };
    if (status) query.status = status;

    const payments = await MerchantPayment.find(query)
      .populate('merchant', 'merchantId merchantName')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await MerchantPayment.countDocuments(query);

    res.status(200).json({
      success: true,
      data: {
        payments,
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

// ==================== ADMIN APIs ====================

/**
 * @desc    ສ້າງຮ້ານຄ້າໃໝ່
 * @route   POST /api/merchant/admin/create
 * @access  Private (Admin)
 */
exports.createMerchant = async (req, res, next) => {
  try {
    const {
      merchantName,
      ownerName,
      phone,
      email,
      address,
      bankName,
      accountNumber,
      accountName,
      feePercent,
    } = req.body;

    // Validate
    if (!merchantName || !ownerName || !phone || !bankName || !accountNumber || !accountName) {
      return res.status(400).json({
        success: false,
        message: 'ກະລຸນາປ້ອນຂໍ້ມູນໃຫ້ຄົບ',
      });
    }

    const merchant = await Merchant.create({
      merchantName,
      ownerName,
      phone,
      email,
      address,
      bankInfo: {
        bankName,
        accountNumber,
        accountName,
      },
      feePercent: feePercent || 1.5,
    });

    res.status(201).json({
      success: true,
      message: 'ສ້າງຮ້ານຄ້າສຳເລັດ',
      data: {
        merchantId: merchant.merchantId,
        merchantName: merchant.merchantName,
        qrCodeId: merchant.qrCodeId,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ດຶງລາຍຊື່ຮ້ານຄ້າທັງໝົດ
 * @route   GET /api/merchant/admin/list
 * @access  Private (Admin)
 */
exports.getAllMerchants = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, isActive } = req.query;

    const query = {};
    if (isActive !== undefined) {
      query.isActive = isActive === 'true';
    }

    const merchants = await Merchant.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const total = await Merchant.countDocuments(query);

    res.status(200).json({
      success: true,
      data: {
        merchants,
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
 * @desc    ດຶງຍອດເງິນ Pool Wallet
 * @route   GET /api/merchant/admin/pool/balance
 * @access  Private (Admin)
 */
exports.getPoolBalance = async (req, res, next) => {
  try {
    const balance = await poolWalletService.getPoolBalance();

    res.status(200).json({
      success: true,
      data: balance,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ດຶງ failed payments
 * @route   GET /api/merchant/admin/failed
 * @access  Private (Admin)
 */
exports.getFailedPayments = async (req, res, next) => {
  try {
    const payments = await MerchantPayment.find({
      status: 'failed',
      retryCount: { $lt: 3 },
    })
      .populate('merchant', 'merchantId merchantName')
      .populate('user', 'fullName phone')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      data: payments,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Retry failed payment
 * @route   POST /api/merchant/admin/retry/:id
 * @access  Private (Admin)
 */
exports.retryPayment = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await poolWalletService.retryFailedPayment(id);

    res.status(200).json({
      success: true,
      message: 'Retry ສຳເລັດ',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    ສະຖິຕິລວມ
 * @route   GET /api/merchant/admin/stats
 * @access  Private (Admin)
 */
exports.getStats = async (req, res, next) => {
  try {
    const [
      totalMerchants,
      activeMerchants,
      totalPayments,
      completedPayments,
      failedPayments,
      poolBalance,
    ] = await Promise.all([
      Merchant.countDocuments(),
      Merchant.countDocuments({ isActive: true }),
      MerchantPayment.countDocuments(),
      MerchantPayment.countDocuments({ status: 'completed' }),
      MerchantPayment.countDocuments({ status: 'failed' }),
      poolWalletService.getPoolBalance().catch(() => null),
    ]);

    // ສະຖິຕິວັນນີ້
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const todayStats = await MerchantPayment.aggregate([
      {
        $match: {
          createdAt: { $gte: today },
          status: 'completed',
        },
      },
      {
        $group: {
          _id: null,
          count: { $sum: 1 },
          totalLAK: { $sum: '$amountLAK' },
          totalSats: { $sum: '$amountSats' },
          totalFees: { $sum: '$feeLAK' },
        },
      },
    ]);

    res.status(200).json({
      success: true,
      data: {
        merchants: {
          total: totalMerchants,
          active: activeMerchants,
        },
        payments: {
          total: totalPayments,
          completed: completedPayments,
          failed: failedPayments,
        },
        today: todayStats[0] || { count: 0, totalLAK: 0, totalSats: 0, totalFees: 0 },
        poolWallet: poolBalance,
      },
    });
  } catch (error) {
    next(error);
  }
};