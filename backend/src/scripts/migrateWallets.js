const mongoose = require('mongoose');
const User = require('../models/User');
const Wallet = require('../models/Wallet');
require('dotenv').config();

async function migrateWallets() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('Connected to MongoDB');

    // ດຶງ users ທີ່ມີ lnbitsWallet
    const users = await User.find({ 'lnbitsWallet.walletId': { $ne: null } })
      .select('+lnbitsWallet.adminKey +lnbitsWallet.invoiceKey');

    console.log(`Found ${users.length} users with wallets`);

    for (const user of users) {
      // ກວດວ່າມີ wallet ແລ້ວບໍ່
      const existingWallet = await Wallet.findOne({ 
        walletId: user.lnbitsWallet.walletId 
      });

      if (existingWallet) {
        console.log(`Wallet already exists for user: ${user.email}`);
        continue;
      }

      // ສ້າງ wallet ໃໝ່
      await Wallet.create({
        user: user._id,
        walletId: user.lnbitsWallet.walletId,
        walletName: user.lnbitsWallet.walletName,
        adminKey: user.lnbitsWallet.adminKey,
        invoiceKey: user.lnbitsWallet.invoiceKey,
        balance: user.lnbitsWallet.balance || 0,
        isDefault: true,
        createdAt: user.lnbitsWallet.createdAt || new Date(),
      });

      console.log(`✅ Migrated wallet for: ${user.email}`);
    }

    console.log('Migration completed!');
    process.exit(0);
  } catch (error) {
    console.error('Migration error:', error);
    process.exit(1);
  }
}

migrateWallets();