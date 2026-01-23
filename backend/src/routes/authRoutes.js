const express = require('express');
const router = express.Router();
const passport = require('passport');
const { body, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');

// Import controller properly
const authController = require('../controllers/authController');

// ===== Validation Middleware =====
const validateRegister = [
  body('fullName')
    .trim()
    .notEmpty()
    .withMessage('Full name is required')
    .isLength({ min: 2 })
    .withMessage('Full name must be at least 2 characters'),
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
];

const validateLogin = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
  body('password').notEmpty().withMessage('Password is required'),
];

const validateForgotPassword = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
];

const validateResetPassword = [
  body('token').notEmpty().withMessage('Reset token is required'),
  body('newPassword')
    .notEmpty()
    .withMessage('New password is required')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
];

// ⚠️ ເພີ່ມ validation ສໍາລັບ Google Mobile
const validateGoogleMobile = [
  body('email')
    .trim()
    .notEmpty()
    .withMessage('Email is required')
    .isEmail()
    .withMessage('Please provide a valid email')
    .normalizeEmail(),
  body('fullName')
    .optional()
    .trim(),
  body('idToken')
    .optional(),
  body('photoUrl')
    .optional()
    .trim(),
];

// Validation error handler
const handleValidationErrors = (req, res, next) => {
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

// ===== Public Routes =====

/**
 * @route   POST /api/auth/register
 * @desc    Register new user
 * @access  Public
 */
router.post('/register', validateRegister, handleValidationErrors, authController.register);

/**
 * @route   POST /api/auth/login
 * @desc    Login user
 * @access  Public
 */
router.post('/login', validateLogin, handleValidationErrors, authController.login);

// ===== Google OAuth Routes =====

/**
 * @route   GET /api/auth/google
 * @desc    Google OAuth - Web (ເປີດໜ້າ Google login)
 * @access  Public
 */
router.get('/google', passport.authenticate('google', { scope: ['profile', 'email'] }));

/**
 * @route   GET /api/auth/google/callback
 * @desc    Google OAuth callback - Web
 * @access  Public
 */
router.get('/google/callback', (req, res, next) => {
  passport.authenticate('google', { session: false }, async (err, user, info) => {
    if (err) return next(err);
    if (!user) {
      return res.redirect(`${process.env.FRONTEND_URL || 'http://localhost:3000'}/login?error=google_auth_failed`);
    }

    try {
      // ສ້າງ LNbits wallet ຖ້າຍັງບໍ່ມີ
      if (!user.lnbitsWallet?.walletId) {
        const lnbitsService = require('../services/lnbitsService');
        try {
          const walletData = await lnbitsService.createWallet(
            `${user.fullName.replace(/\s+/g, '_')}_wallet`
          );
          user.lnbitsWallet = {
            walletId: walletData.walletId,
            walletName: walletData.walletName,
            adminKey: walletData.adminKey,
            invoiceKey: walletData.invoiceKey,
            balance: 0,
            createdAt: new Date(),
          };
          await user.save();
        } catch (walletError) {
          console.error('Wallet creation failed:', walletError.message);
        }
      }

      user.lastLogin = new Date();
      await user.save();

      // ສ້າງ JWT tokens
      const { generateAccessToken, generateRefreshToken } = require('../utils/jwt');
      const accessToken = generateAccessToken(user._id);
      const refreshToken = generateRefreshToken(user._id);

      // Redirect ໄປ Frontend
      const redirectUrl = `${process.env.FRONTEND_URL}/auth/callback?access_token=${accessToken}&refresh_token=${refreshToken}`;
      return res.redirect(redirectUrl);
    } catch (error) {
      return next(error);
    }
  })(req, res, next);
});

/**
 * @route   POST /api/auth/google-mobile
 * @desc    Google Sign In for Mobile Apps (Flutter, React Native)
 * @access  Public
 */
router.post(
  '/google-mobile',
  validateGoogleMobile,
  handleValidationErrors,
  authController.googleMobileSignIn
);

// ===== Password Reset Routes =====

/**
 * @route   POST /api/auth/forgot-password
 * @desc    Send password reset email
 * @access  Public
 */
router.post(
  '/forgot-password',
  validateForgotPassword,
  handleValidationErrors,
  authController.forgotPassword
);

/**
 * @route   POST /api/auth/reset-password
 * @desc    Reset password with token
 * @access  Public
 */
router.post(
  '/reset-password',
  validateResetPassword,
  handleValidationErrors,
  authController.resetPassword
);

// ===== Protected Routes =====

/**
 * @route   GET /api/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', protect, authController.getMe);

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user
 * @access  Private
 */
router.post('/logout', protect, authController.logout);

module.exports = router;