const mongoose = require('mongoose');

/**
 * MerchantPayment - ບັນທຶກການຈ່າຍເງິນໃຫ້ຮ້ານຄ້າ
 * 
 * Flow:
 * 1. User ຈ່າຍ Sats → Admin Pool (LNBits)
 * 2. ເມື່ອ Sats ເຂົ້າແລ້ວ → Sabaidee Wallet ຈ່າຍ LAK ໃຫ້ຮ້ານຄ້າ
 */
const MerchantPaymentSchema = new mongoose.Schema({
  // ອ້າງອີງ
  merchant: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Merchant',
    required: true,
  },
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  originalTransaction: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Transaction',
  },

  // Payment Hash ຈາກ LNBits
  paymentHash: {
    type: String,
    required: true,
    index: true,
  },

  // ຈຳນວນເງິນ
  amountSats: {
    type: Number,
    required: true,
  },
  amountLAK: {
    type: Number,
    required: true,
  },
  exchangeRate: {
    type: Number,
    required: true,
  },

  // ຄ່າທຳນຽມ
  feePercent: {
    type: Number,
    default: 1.5,
  },
  feeLAK: {
    type: Number,
    default: 0,
  },
  netAmountLAK: {
    type: Number,
    required: true,
  },

  // ສະຖານະ
  status: {
    type: String,
    enum: ['pending', 'sats_received', 'processing', 'completed', 'failed'],
    default: 'pending',
  },

  // ບັນທຶກເວລາ Sats ເຂົ້າ Admin Pool
  satsReceivedAt: Date,

  // ຂໍ້ມູນການໂອນ LAK (ຈາກ Sabaidee Wallet ໄປ ຮ້ານຄ້າ)
  bankTransfer: {
    bankName: String,
    accountNumber: String,
    accountName: String,
    referenceNumber: String,
    transferredAt: Date,
    paidBy: {
      type: String,
      default: 'SABAIDEE_WALLET',
    },
  },

  memo: String,
  errorMessage: String,
  retryCount: {
    type: Number,
    default: 0,
  },

  createdAt: {
    type: Date,
    default: Date.now,
  },
  completedAt: Date,
});

// Indexes
MerchantPaymentSchema.index({ merchant: 1, status: 1 });
MerchantPaymentSchema.index({ user: 1, createdAt: -1 });
MerchantPaymentSchema.index({ paymentHash: 1 });

module.exports = mongoose.model('MerchantPayment', MerchantPaymentSchema);