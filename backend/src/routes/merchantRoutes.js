/**
 * Merchant Routes
 * /api/merchant
 */

const express = require('express');
const router = express.Router();

const {
  getMerchantByQR,
  createPayment,
  checkPayment,
  getPaymentHistory,
  createMerchant,
  getAllMerchants,
  getPoolBalance,
  getFailedPayments,
  retryPayment,
  getStats,
} = require('../controllers/merchantController');

const { protect } = require('../middleware/auth');

// ==================== USER ROUTES ====================

// ດຶງຂໍ້ມູນຮ້ານຄ້າຈາກ QR
router.get('/info/:qrCodeId', protect, getMerchantByQR);

// ສ້າງການຈ່າຍເງິນ (User scan QR)
router.post('/pay', protect, createPayment);

// ກວດສອບ ແລະ ດຳເນີນການຈ່າຍ
router.post('/pay/check', protect, checkPayment);

// ປະຫວັດການຈ່າຍເງິນ
router.get('/history', protect, getPaymentHistory);

// ==================== ADMIN ROUTES ====================
// TODO: ເພີ່ມ admin middleware ຖ້າຕ້ອງການ

// ສ້າງຮ້ານຄ້າໃໝ່
router.post('/admin/create', protect, createMerchant);

// ລາຍຊື່ຮ້ານຄ້າ
router.get('/admin/list', protect, getAllMerchants);

// ຍອດເງິນ Pool
router.get('/admin/pool/balance', protect, getPoolBalance);

// Failed payments
router.get('/admin/failed', protect, getFailedPayments);

// Retry payment
router.post('/admin/retry/:id', protect, retryPayment);

// ສະຖິຕິ
router.get('/admin/stats', protect, getStats);

module.exports = router;