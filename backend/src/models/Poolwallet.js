const mongoose = require('mongoose');

/**
 * PoolWallet - Admin Pool Wallet (LNBits)
 * 
 * ໜ້າທີ່: ເກັບ Sats ທີ່ User ຈ່າຍມາ
 * Sabaidee Wallet (ບັນຊີບໍລິສັດ) ຈະຈ່າຍ LAK ໃຫ້ຮ້ານຄ້າແທນ
 */
const PoolWalletSchema = new mongoose.Schema({
  // LNBits Wallet Info
  walletId: {
    type: String,
    required: true,
    unique: true,
  },
  walletName: {
    type: String,
    default: 'SABAIDEE_ADMIN_POOL',
  },
  adminKey: {
    type: String,
    required: true,
    select: false,
  },
  invoiceKey: {
    type: String,
    required: true,
    select: false,
  },

  // Balance (Sats ທີ່ເກັບໄວ້)
  balanceSats: {
    type: Number,
    default: 0,
  },

  // ສະຖິຕິ
  totalSatsReceived: {
    type: Number,
    default: 0,
  },
  totalLakPaidOut: {
    type: Number,
    default: 0,
  },
  totalFeeCollected: {
    type: Number,
    default: 0,
  },
  totalTransactions: {
    type: Number,
    default: 0,
  },

  // Sabaidee Wallet (ບັນຊີບໍລິສັດ) Info
  companyAccount: {
    bankName: {
      type: String,
      default: 'BCEL',
    },
    accountNumber: String,
    accountName: {
      type: String,
      default: 'Sabaidee Wallet Co., Ltd',
    },
  },

  isActive: {
    type: Boolean,
    default: true,
  },
  isPrimary: {
    type: Boolean,
    default: true,
  },

  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('PoolWallet', PoolWalletSchema);