const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const { protect } = require('../middleware/auth');
const walletController = require('../controllers/walletController');

// Validation middleware
const validateCreateInvoice = [
  body('amount')
    .notEmpty()
    .withMessage('Amount is required')
    .isInt({ min: 1 })
    .withMessage('Amount must be a positive integer'),
  body('memo')
    .optional()
    .trim()
    .isLength({ max: 200 })
    .withMessage('Memo must not exceed 200 characters'),
];

const validatePayInvoice = [
  body('bolt11')
    .notEmpty()
    .withMessage('Lightning invoice (bolt11) is required')
    .trim(),
];

const validateSendPayment = [
  body('toWalletId')
    .notEmpty()
    .withMessage('Wallet ID is required')
    .trim(),
  body('amount')
    .notEmpty()
    .withMessage('Amount is required')
    .isInt({ min: 1 })
    .withMessage('Amount must be positive'),
];

// Validation error handler
const handleValidationErrors = (req, res, next) => {
  const { validationResult } = require('express-validator');
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array(),
    });
  }
  next();
};

// All routes are protected
router.use(protect);

// @route   GET /api/wallet/balance
router.get('/balance', walletController.getBalance);

// @route   GET /api/wallet/details
router.get('/details', walletController.getWalletDetails);

// @route   POST /api/wallet/invoice
router.post(
  '/invoice',
  validateCreateInvoice,
  handleValidationErrors,
  walletController.createInvoice
);

// @route   POST /api/wallet/pay
router.post(
  '/pay',
  validatePayInvoice,
  handleValidationErrors,
  walletController.payInvoice
);

// ✅ NEW: Send payment to wallet/merchant
// @route   POST /api/wallet/send
router.post(
  '/send',
  validateSendPayment,
  handleValidationErrors,
  walletController.sendPayment
);

// @route   GET /api/wallet/payments
router.get('/payments', walletController.getPayments);

// @route   GET /api/wallet/payment/:paymentHash
router.get('/payment/:paymentHash', walletController.checkPayment);

// @route   POST /api/wallet/create
router.post('/create', walletController.createWallet);

// @route   GET /api/wallet/transactions
router.get('/transactions', walletController.getTransactions);

// @route   GET /api/wallet/list
router.get('/list', walletController.getWallets);

// @route   GET /api/wallet/rate
router.get('/rate', walletController.getExchangeRate);

module.exports = router;