const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, 'Please provide your full name'],
      trim: true,
    },
    email: {
      type: String,
      required: [true, 'Please provide your email'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [
        /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/,
        'Please provide a valid email',
      ],
    },
    password: {
      type: String,
      minlength: [6, 'Password must be at least 6 characters'],
      select: false, // Don't return password by default
    },
    googleId: {
      type: String,
      sparse: true, // Allow null but must be unique if exists
    },
    avatar: {
      type: String,
      default: null,
    },
    authProvider: {
      type: String,
      enum: ['local', 'google'],
      default: 'local',
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    // LNbits Wallet Information
    // lnbitsWallet: {
    //   walletId: {
    //     type: String,
    //     default: null,
    //   },
    //   walletName: {
    //     type: String,
    //     default: null,
    //   },
    //   adminKey: {
    //     type: String,
    //     select: false, // Security: don't return by default
    //   },
    //   invoiceKey: {
    //     type: String,
    //     select: false,
    //   },
    //   balance: {
    //     type: Number,
    //     default: 0,
    //   },
    //   createdAt: {
    //     type: Date,
    //     default: null,
    //   },
    // },
    resetPasswordToken: {
      type: String,
      select: false,
    },
    resetPasswordExpire: {
      type: Date,
      select: false,
    },
    lastLogin: {
      type: Date,
      default: null,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Hash password before saving
userSchema.pre('save', async function () {
  // Only hash if password is modified or new
  if (!this.isModified('password')) {
    return;
  }

  // Only hash if password exists (Google OAuth users might not have password)
  if (this.password) {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
  }
});

// Method to compare passwords
userSchema.methods.comparePassword = async function (enteredPassword) {
  if (!this.password) {
    return false;
  }
  return await bcrypt.compare(enteredPassword, this.password);
};

// Method to get public user data (without sensitive info)
// userSchema.methods.toPublicJSON = function () {
//    // ✅ ດຶງ wallet ຈາກ Wallet collection
//   const Wallet = mongoose.model('Wallet');
//   const wallet = await Wallet.findOne({ user: this._id, isDefault: true })
//     .select('+invoiceKey');

//   return {
//     id: this._id,
//     fullName: this.fullName,
//     email: this.email,
//     profilePhoto: this.avatar,
//     authProvider: this.authProvider,
//     isVerified: this.isVerified,
//     isActive: this.isActive,
//     role: 'user',
//     isAdmin: false,
//     googleId: this.googleId,
//     lnbitsWallet: wallet ? {
//       walletId: wallet.walletId,
//       walletName: wallet.walletName,
//       balance: wallet.balance || 0,
//       invoiceKey: wallet.invoiceKey,
//       createdAt: wallet.createdAt,
//     } : null,
//     lastLogin: this.lastLogin,
//     createdAt: this.createdAt,
//   };
// };

module.exports = mongoose.model('User', userSchema);