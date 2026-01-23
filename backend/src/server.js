require('dotenv').config();
const express = require('express');
const cors = require('cors');
const passport = require('passport');
const connectDB = require('./config/database');

// Import routes
const authRoutes = require('./routes/authRoutes');
const walletRoutes = require('./routes/walletRoutes');
const merchantRoutes = require('./routes/merchantRoutes'); // ✅ ເພີ່ມໃໝ່

// Initialize express app
const app = express();

// Connect to MongoDB
connectDB();

// CORS configuration
app.use(cors({
  origin: '*',
  credentials: true,
}));

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(` ${req.method} ${req.path}`);
  // ✅ ເພີ່ມ null check
  if (req.body && Object.keys(req.body).length > 0) {
    console.log('Body:', req.body);
  }
  next();
});

// Initialize Passport
try {
  require('./config/passport');
  app.use(passport.initialize());
  console.log('✅ Passport initialized');
} catch (error) {
  console.log('⚠️  Passport config not found, skipping Google OAuth');
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Server is running',
    timestamp: new Date().toISOString(),
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.status(200).json({
    success: true,
    message: 'Sabaidee Wallet API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      auth: '/api/auth',
      wallet: '/api/wallet',
      merchant: '/api/merchant', // ✅ ເພີ່ມໃໝ່
    },
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/wallet', walletRoutes);
app.use('/api/merchant', merchantRoutes); // ✅ ເພີ່ມໃໝ່

// 404 handler
app.use((req, res, next) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
    path: req.path,
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('❌ Error:', err);
  
  let error = {
    success: false,
    message: err.message || 'Internal Server Error',
  };

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    error.message = Object.values(err.errors)
      .map(e => e.message)
      .join(', ');
    return res.status(400).json(error);
  }

  // Mongoose duplicate key error
  if (err.code === 11000) {
    error.message = 'ຂໍ້ມູນຊ້ຳກັນ';
    return res.status(400).json(error);
  }

  // JWT error
  if (err.name === 'JsonWebTokenError') {
    error.message = 'Token ບໍ່ຖືກຕ້ອງ';
    return res.status(401).json(error);
  }

  res.status(err.statusCode || 500).json(error);
});

// Start server
const PORT = process.env.PORT || 5000;

const server = app.listen(PORT, () => {
  console.log(`
   ========================================
   ✅ Sabaidee Wallet Server
   ✅ Port: ${PORT}
   ✅ Environment: ${process.env.NODE_ENV || 'development'}
   ========================================
  `);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (err) => {
  console.error('❌ Unhandled Rejection:', err);
  server.close(() => process.exit(1));
});

module.exports = app;