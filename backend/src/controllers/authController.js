const User = require('../models/User');
const Wallet = require('../models/Wallet');  // ✅ ເພີ່ມ
const lnbitsService = require('../services/lnbitsService');
const emailService = require('../services/emailService');
const { generateAccessToken, generateRefreshToken } = require('../utils/jwt');
const crypto = require('crypto');

/**
 * @desc    Register new user
 * @route   POST /api/auth/register
 * @access  Public
 */
exports.register = async (req, res, next) => {
  try {
    const { fullName, email, password } = req.body;

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email is already registered',
      });
    }

    // Create user
    const user = await User.create({
      fullName,
      email,
      password,
      authProvider: 'local',
    });

    // ✅ ສ້າງ wallet ໃນ Wallet collection
    let wallet = null;
    try {
      const walletName = `${fullName.replace(/\s+/g, '_')}_wallet`;
      const walletData = await lnbitsService.createWallet(walletName);

      wallet = await Wallet.create({
        user: user._id,
        walletId: walletData.walletId,
        walletName: walletData.walletName,
        adminKey: walletData.adminKey,
        invoiceKey: walletData.invoiceKey,
        balance: 0,
        isDefault: true,
      });

      console.log(`✅ LNbits wallet created for user: ${email}`);
    } catch (walletError) {
      console.error('❌ LNbits wallet creation failed:', walletError.message);
    }

    // Send welcome email (non-blocking)
    try {
      await emailService.sendWelcomeEmail(email, fullName);
    } catch (emailError) {
      console.error('Failed to send welcome email:', emailError);
    }

    // Generate tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    // ✅ ສ້າງ response ພ້ອມ wallet
    const userResponse = buildUserResponse(user, wallet);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: {
        user: userResponse,
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Login user
 * @route   POST /api/auth/login
 * @access  Public
 */
exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email and password',
      });
    }

    // Get user with password
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Check if user registered with Google
    if (user.authProvider === 'google' && !user.password) {
      return res.status(400).json({
        success: false,
        message: 'This account is registered with Google. Please use Google Sign-In.',
      });
    }

    // Verify password
    const isPasswordValid = await user.comparePassword(password);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials',
      });
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // ✅ ດຶງ wallet ຈາກ Wallet collection
    let wallet = await Wallet.findOne({ user: user._id, isDefault: true })
      .select('+adminKey +invoiceKey');

    // Update wallet balance if exists
    if (wallet) {
      try {
        const balance = await lnbitsService.getWalletBalance(wallet.adminKey);
        wallet.balance = balance;
        await wallet.save();
      } catch (error) {
        console.error('Failed to update wallet balance:', error.message);
      }
    }

    // Generate tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    // ✅ ສ້າງ response ພ້ອມ wallet
    const userResponse = buildUserResponse(user, wallet);

    res.status(200).json({
      success: true,
      message: 'Login successful',
      data: {
        user: userResponse,
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Google Sign In for Mobile Apps
 * @route   POST /api/auth/google-mobile
 * @access  Public
 */
exports.googleMobileSignIn = async (req, res, next) => {
  try {
    const { idToken, email, fullName, photoUrl } = req.body;

    console.log('🔵 Google Mobile Sign In Request:', { email, fullName });

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required',
      });
    }

    let user = await User.findOne({ email });
    let wallet = null;

    if (!user) {
      console.log('🆕 Creating new Google user:', email);
      
      // Create new user
      user = await User.create({
        email,
        fullName: fullName || email.split('@')[0],
        authProvider: 'google',
        googleId: email,
        avatar: photoUrl,
        isVerified: true,
        isActive: true,
      });

      // ✅ ສ້າງ wallet ໃນ Wallet collection
      try {
        const walletName = `${(fullName || email.split('@')[0]).replace(/\s+/g, '_')}_wallet`;
        const walletData = await lnbitsService.createWallet(walletName);

        wallet = await Wallet.create({
          user: user._id,
          walletId: walletData.walletId,
          walletName: walletData.walletName,
          adminKey: walletData.adminKey,
          invoiceKey: walletData.invoiceKey,
          balance: 0,
          isDefault: true,
        });

        console.log(`✅ LNbits wallet created for Google user: ${email}`);
      } catch (walletError) {
        console.error('❌ Wallet creation failed:', walletError.message);
      }

      // Send welcome email
      try {
        await emailService.sendWelcomeEmail(email, fullName || email.split('@')[0]);
      } catch (emailError) {
        console.error('Failed to send welcome email:', emailError);
      }
    } else {
      console.log('👤 Existing Google user logging in:', email);
      
      // Update last login
      user.lastLogin = new Date();
      
      if (photoUrl && !user.avatar) {
        user.avatar = photoUrl;
      }

      await user.save();

      // ✅ ດຶງ wallet ຈາກ Wallet collection
      wallet = await Wallet.findOne({ user: user._id, isDefault: true })
        .select('+adminKey +invoiceKey');

      // Update wallet balance
      if (wallet) {
        try {
          const balance = await lnbitsService.getWalletBalance(wallet.adminKey);
          wallet.balance = balance;
          await wallet.save();
        } catch (error) {
          console.error('Failed to update wallet balance:', error.message);
        }
      }
    }

    // Generate tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    // ✅ ສ້າງ response ພ້ອມ wallet
    const userResponse = buildUserResponse(user, wallet);

    console.log('✅ Google Mobile Sign In successful:', email);

    res.status(200).json({
      success: true,
      message: 'Google sign in successful',
      data: {
        user: userResponse,
        accessToken,
        refreshToken,
      },
    });
  } catch (error) {
    console.error('❌ Google Mobile Sign In Error:', error);
    next(error);
  }
};

/**
 * @desc    Google OAuth callback (for web)
 * @route   GET /api/auth/google/callback
 * @access  Public
 */
exports.googleCallback = async (req, res, next) => {
  try {
    const user = req.user;

    // ✅ ກວດ/ສ້າງ wallet ໃນ Wallet collection
    let wallet = await Wallet.findOne({ user: user._id, isDefault: true });

    if (!wallet) {
      try {
        const walletName = `${user.fullName.replace(/\s+/g, '_')}_wallet`;
        const walletData = await lnbitsService.createWallet(walletName);

        wallet = await Wallet.create({
          user: user._id,
          walletId: walletData.walletId,
          walletName: walletData.walletName,
          adminKey: walletData.adminKey,
          invoiceKey: walletData.invoiceKey,
          balance: 0,
          isDefault: true,
        });
      } catch (walletError) {
        console.error('Wallet creation failed:', walletError.message);
      }
    }

    // Update last login
    user.lastLogin = new Date();
    await user.save();

    // Generate tokens
    const accessToken = generateAccessToken(user._id);
    const refreshToken = generateRefreshToken(user._id);

    // Redirect to frontend with tokens
    const redirectUrl = `${process.env.FRONTEND_URL}/auth/callback?access_token=${accessToken}&refresh_token=${refreshToken}`;
    res.redirect(redirectUrl);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Forgot password - send reset email
 * @route   POST /api/auth/forgot-password
 * @access  Public
 */
exports.forgotPassword = async (req, res, next) => {
  try {
    const { email } = req.body;

    const user = await User.findOne({ email });

    if (!user) {
      return res.status(200).json({
        success: true,
        message: 'If an account exists with this email, a password reset link has been sent.',
      });
    }

    if (user.authProvider === 'google' && !user.password) {
      return res.status(400).json({
        success: false,
        message: 'This account is registered with Google. Password reset is not applicable.',
      });
    }

    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    
    user.resetPasswordToken = crypto
      .createHash('sha256')
      .update(resetToken)
      .digest('hex');
    
    user.resetPasswordExpire = Date.now() + parseInt(process.env.RESET_TOKEN_EXPIRE || 3600000);
    
    await user.save();

    try {
      await emailService.sendPasswordResetEmail(
        user.email,
        resetToken,
        user.fullName
      );

      res.status(200).json({
        success: true,
        message: 'Password reset email sent successfully',
      });
    } catch (emailError) {
      user.resetPasswordToken = undefined;
      user.resetPasswordExpire = undefined;
      await user.save();

      return res.status(500).json({
        success: false,
        message: 'Failed to send reset email. Please try again.',
      });
    }
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Reset password with token
 * @route   POST /api/auth/reset-password
 * @access  Public
 */
exports.resetPassword = async (req, res, next) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Please provide token and new password',
      });
    }

    const hashedToken = crypto
      .createHash('sha256')
      .update(token)
      .digest('hex');

    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpire: { $gt: Date.now() },
    }).select('+resetPasswordToken +resetPasswordExpire');

    if (!user) {
      return res.status(400).json({
        success: false,
        message: 'Invalid or expired reset token',
      });
    }

    user.password = newPassword;
    user.resetPasswordToken = undefined;
    user.resetPasswordExpire = undefined;

    await user.save();

    res.status(200).json({
      success: true,
      message: 'Password reset successful. You can now login with your new password.',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get current user profile
 * @route   GET /api/auth/me
 * @access  Private
 */
exports.getMe = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    // ✅ ດຶງ wallet ຈາກ Wallet collection
    let wallet = await Wallet.findOne({ user: user._id, isDefault: true })
      .select('+adminKey +invoiceKey');

    // Update wallet balance
    if (wallet) {
      try {
        const balance = await lnbitsService.getWalletBalance(wallet.adminKey);
        wallet.balance = balance;
        await wallet.save();
      } catch (error) {
        console.error('Failed to update balance:', error.message);
      }
    }

    // ✅ ສ້າງ response ພ້ອມ wallet
    const userResponse = buildUserResponse(user, wallet);

    res.status(200).json({
      success: true,
      data: userResponse,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Logout user
 * @route   POST /api/auth/logout
 * @access  Private
 */
exports.logout = async (req, res, next) => {
  try {
    res.status(200).json({
      success: true,
      message: 'Logout successful',
    });
  } catch (error) {
    next(error);
  }
};

// ✅ Helper function ສ້າງ user response
function buildUserResponse(user, wallet) {
  return {
    _id: user._id,
    fullName: user.fullName,
    email: user.email,
    profilePhoto: user.avatar,
    authProvider: user.authProvider,
    isVerified: user.isVerified,
    isActive: user.isActive,
    role: 'user',
    isAdmin: false,
    googleId: user.googleId,
    lastLogin: user.lastLogin,
    createdAt: user.createdAt,
    lnbitsWallet: wallet ? {
      walletId: wallet.walletId,
      walletName: wallet.walletName,
      balance: wallet.balance || 0,
      invoiceKey: wallet.invoiceKey,
      createdAt: wallet.createdAt,
    } : null,
  };
}