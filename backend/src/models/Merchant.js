const mongoose = require('mongoose');

const MerchantSchema = new mongoose.Schema({
  // ຂໍ້ມູນພື້ນຖານ
  merchantId: {
    type: String,
    unique: true,
  },
  merchantName: {
    type: String,
    required: [true, 'ກະລຸນາປ້ອນຊື່ຮ້ານຄ້າ'],
  },
  ownerName: {
    type: String,
    required: [true, 'ກະລຸນາປ້ອນຊື່ເຈົ້າຂອງ'],
  },
  phone: {
    type: String,
    required: [true, 'ກະລຸນາປ້ອນເບີໂທ'],
  },
  email: {
    type: String,
    sparse: true,
  },
  address: String,

  // ຂໍ້ມູນທະນາຄານ (ສຳລັບຮັບເງິນກີບຈາກ Sabaidee Wallet)
  bankInfo: {
    bankName: {
      type: String,
      enum: ['BCEL', 'JDB', 'LDB', 'APB', 'BFL', 'ICB', 'OTHER'],
      required: [true, 'ກະລຸນາເລືອກທະນາຄານ'],
    },
    accountNumber: {
      type: String,
      required: [true, 'ກະລຸນາປ້ອນເລກບັນຊີ'],
    },
    accountName: {
      type: String,
      required: [true, 'ກະລຸນາປ້ອນຊື່ບັນຊີ'],
    },
  },

  // QR Code ID (unique identifier ສຳລັບ scan)
  qrCodeId: {
    type: String,
    unique: true,
  },

  // ສະຖານະ
  isActive: {
    type: Boolean,
    default: true,
  },
  isVerified: {
    type: Boolean,
    default: false,
  },

  // ຄ່າທຳນຽມ (%)
  feePercent: {
    type: Number,
    default: 1.5,
    min: 0,
    max: 10,
  },

  // ສະຖິຕິ
  totalTransactions: {
    type: Number,
    default: 0,
  },
  totalAmountLAK: {
    type: Number,
    default: 0,
  },
  totalAmountSats: {
    type: Number,
    default: 0,
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

// Auto-generate merchantId ແລະ qrCodeId
MerchantSchema.pre('save', async function(next) {
  try {
    if (!this.merchantId) {
      const count = await this.constructor.countDocuments();
      this.merchantId = `MER${String(count + 1).padStart(6, '0')}`;
    }
    if (!this.qrCodeId) {
      this.qrCodeId = `QR_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }
    this.updatedAt = Date.now();
    next();
  } catch (error) {
    next(error);
  }
});

module.exports = mongoose.model('Merchant', MerchantSchema);