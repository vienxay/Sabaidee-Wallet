const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },

   wallet: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Wallet',  // ✅ ເພີ່ມ reference ໄປ Wallet
  },
  
  // LNbits data
  paymentHash: {
    type: String,
    required: true,
    unique: true,
  },
  
  // ປະເພດ: receive (ຮັບ) ຫຼື send (ສົ່ງ)
  type: {
    type: String,
    enum: ['receive', 'send'],
    required: true,
  },
  
  // ຈຳນວນເງິນ
  amountLAK: {
    type: Number,
    required: true,
  },
  amountSats: {
    type: Number,
    required: true,
  },
  
  // ສະຖານະ
  status: {
    type: String,
    enum: ['pending', 'completed', 'failed', 'expired'],
    default: 'pending',
  },
  
  // ລາຍລະອຽດ
  memo: {
    type: String,
    default: '',
  },
  
  // Invoice (ສຳລັບ receive)
  bolt11: {
    type: String,
  },
  
  // ເວລາ
  createdAt: {
    type: Date,
    default: Date.now,
  },
  completedAt: {
    type: Date,
  },
  expiresAt: {
    type: Date,
  },
  
  // Exchange rate ຕອນສ້າງ
  exchangeRate: {
    type: Number,
  },
});

// Index ສຳລັບ query ໄວ
transactionSchema.index({ user: 1, createdAt: -1 });
transactionSchema.index({ wallet: 1, createdAt: -1 });
transactionSchema.index({ paymentHash: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);