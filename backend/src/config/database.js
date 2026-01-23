const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGODB_URI);

        console.log(`MongoDB Connected: ເຊື່ອມຕໍ່ຖານຈໍ້ມູນສຳເລັດ`);
        console.log(`Database: ${conn.connection.name}`);
    } catch (error) {
        console.log('MongoDB Connection Error:', error.message);
        process.exit(1);
    }
};

// Handle MongoDB events
mongoose.connection.on('disconnected', () => {
    console.log('MogoDB Disconnected');
})

mongoose.connection.on('error', (err) => {
    console.error('MongoDB Error:', err);
})

module.exports = connectDB;