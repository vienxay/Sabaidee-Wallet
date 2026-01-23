const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      service: process.env.EMAIL_SERVICE,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD,
      },
    });
  }

  /**
   * Send password reset email
   * @param {string} email - Recipient email
   * @param {string} resetToken - Reset token
   * @param {string} userName - User's name
   */
  async sendPasswordResetEmail(email, resetToken, userName) {
    const resetUrl = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;

    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'Password Reset Request - Laos Wallet',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
            }
            .container {
              padding: 20px;
              background-color: #f5f5f5;
            }
            .content {
              background-color: white;
              padding: 30px;
              border-radius: 10px;
              box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            }
            .header {
              text-align: center;
              color: #FF9933;
              margin-bottom: 20px;
            }
            .button {
              display: inline-block;
              padding: 12px 30px;
              background-color: #FF9933;
              color: white;
              text-decoration: none;
              border-radius: 8px;
              margin: 20px 0;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              font-size: 12px;
              color: #666;
            }
            .warning {
              background-color: #fff3cd;
              border: 1px solid #ffc107;
              padding: 10px;
              border-radius: 5px;
              margin: 15px 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="content">
              <h1 class="header"> Password Reset Request</h1>
              
              <p>ສະບາຍດີ ${userName},</p>
              
              <p>ພວກເຮົາໄດ້ຮັບການຮ້ອງຂໍໃຫ້ປ່ຽນລະຫັດຜ່ານຂອງບັນຊີ Laos Wallet ຂອງເຈົ້າ.</p>
              
              <p>ກົດປຸ່ມດ້ານລຸ່ມເພື່ອປ່ຽນລະຫັດຜ່ານຂອງເຈົ້າ:</p>
              
              <div style="text-align: center;">
                <a href="${resetUrl}" class="button">Reset Password</a>
              </div>
              
              <p>ຫຼື copy ແລະ paste URL ນີ້ໃສ່ໃນ browser:</p>
              <p style="word-break: break-all; color: #0066cc;">${resetUrl}</p>
              
              <div class="warning">
                <strong> ໝາຍເຫດສຳຄັນ:</strong>
                <ul>
                  <li>Link ນີ້ຈະໝົດອາຍຸພາຍໃນ 1 ຊົ່ວໂມງ</li>
                  <li>ຖ້າເຈົ້າບໍ່ໄດ້ຮ້ອງຂໍການປ່ຽນລະຫັດຜ່ານ, ກະລຸນາລະເລີຍ email ນີ້</li>
                  <li>ຢ່າແບ່ງປັນ link ນີ້ກັບຄົນອື່ນ</li>
                </ul>
              </div>
              
              <p>ຖ້າເຈົ້າມີບັນຫາ, ກະລຸນາຕິດຕໍ່ທີມງານຂອງພວກເຮົາ.</p>
              
              <p>ດ້ວຍຄວາມເຄົາລົບ,<br>Laos Wallet Team</p>
            </div>
            
            <div class="footer">
              <p>© 2024 Laos Wallet. All rights reserved.</p>
              <p>Email ນີ້ຖືກສົ່ງອັດຕະໂນມັດ, ກະລຸນາຢ່າຕອບກັບ.</p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      console.log(' Password reset email sent to:', email);
      return true;
    } catch (error) {
      console.error(' Email send error:', error);
      throw new Error('Failed to send email');
    }
  }

  /**
   * Send welcome email after registration
   * @param {string} email - Recipient email
   * @param {string} userName - User's name
   */
  async sendWelcomeEmail(email, userName) {
    const mailOptions = {
      from: process.env.EMAIL_FROM,
      to: email,
      subject: 'Welcome to Laos Wallet! ',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body {
              font-family: Arial, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
            }
            .container {
              padding: 20px;
              background-color: #f5f5f5;
            }
            .content {
              background-color: white;
              padding: 30px;
              border-radius: 10px;
              box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            }
            .header {
              text-align: center;
              color: #FF9933;
              margin-bottom: 20px;
            }
            .footer {
              text-align: center;
              margin-top: 20px;
              font-size: 12px;
              color: #666;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="content">
              <h1 class="header"> ຍິນດີຕ້ອນຮັບ!</h1>
              
              <p>ສະບາຍດີ ${userName},</p>
              
              <p>ຂອບໃຈທີ່ລົງທະບຽນກັບ Laos Wallet! ບັນຊີຂອງເຈົ້າໄດ້ຖືກສ້າງສຳເລັດແລ້ວ.</p>
              
              <p>✨ ບັນຊີ Lightning Wallet ຂອງເຈົ້າໄດ້ຖືກສ້າງອັດຕະໂນມັດແລ້ວ!</p>
              
              <p>ເຈົ້າສາມາດ:</p>
              <ul>
                <li> ຮັບແລະສົ່ງ Bitcoin ຜ່ານ Lightning Network</li>
                <li>⚡ ທຳທຸລະກຳທີ່ຮວດໄວແລະຄ່າທຳນຽມຕໍ່າ</li>
                <li> ຄວາມປອດໄພສູງດ້ວຍ LNbits</li>
              </ul>
              
              <p>ເລີ່ມຕົ້ນໃຊ້ງານໄດ້ເລີຍດຽວນີ້!</p>
              
              <p>ດ້ວຍຄວາມເຄົາລົບ,<br>Laos Wallet Team</p>
            </div>
            
            <div class="footer">
              <p>© 2024 Laos Wallet. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
    };

    try {
      await this.transporter.sendMail(mailOptions);
      console.log(' Welcome email sent to:', email);
    } catch (error) {
      console.error(' Welcome email error:', error);
      // Don't throw error for welcome email, it's not critical
    }
  }
}

module.exports = new EmailService();