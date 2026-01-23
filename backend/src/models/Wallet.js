const mongoose = require('mongoose');

const walletSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  
  // LNbits data
  walletId: {
    type: String,
    required: true,
    unique: true,
  },
  walletName: {
    type: String,
    required: true,
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
  
  // Balance
  balance: {
    type: Number,
    default: 0,
  },
  
  // ສະຖານະ
  isDefault: {
    type: Boolean,
    default: true,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Index
walletSchema.index({ user: 1 });
walletSchema.index({ walletId: 1 });

module.exports = mongoose.model('Wallet', walletSchema);