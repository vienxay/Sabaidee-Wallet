/**
 * EMV QR Code Parser
 * Parse QR codes ຈາກທະນາຄານລາວ (BCEL, JDB, LDB, etc.)
 * 
 * EMV QR Format:
 * - 00: Payload Format Indicator
 * - 01: Point of Initiation (11=static, 12=dynamic)
 * - 26-51: Merchant Account Info
 * - 52: Merchant Category Code
 * - 53: Currency (418 = LAK)
 * - 54: Amount
 * - 58: Country Code (LA)
 * - 59: Merchant Name
 * - 60: Merchant City
 * - 63: CRC Checksum
 */

class EMVQRParser {
  /**
   * Parse EMV QR Code string
   */
  static parse(qrString) {
    const result = {
      isValid: false,
      isEMV: false,
      raw: qrString,
      data: {},
    };

    try {
      // ກວດວ່າເປັນ EMV QR ບໍ (ເລີ່ມດ້ວຍ 000201)
      if (!qrString || !qrString.startsWith('000201')) {
        return result;
      }

      result.isEMV = true;
      
      let position = 0;
      const fields = {};

      while (position < qrString.length - 4) {
        const tag = qrString.substring(position, position + 2);
        const length = parseInt(qrString.substring(position + 2, position + 4), 10);
        
        if (isNaN(length) || length <= 0) break;
        
        const value = qrString.substring(position + 4, position + 4 + length);
        fields[tag] = value;
        position += 4 + length;
      }

      result.data = {
        payloadFormat: fields['00'],
        initiationType: fields['01'], // 11=static, 12=dynamic
        merchantAccount: this.parseMerchantAccount(fields),
        merchantCategoryCode: fields['52'],
        currency: fields['53'], // 418 = LAK
        amount: fields['54'] ? parseFloat(fields['54']) : null,
        countryCode: fields['58'], // LA
        merchantName: fields['59'],
        merchantCity: fields['60'],
        checksum: fields['63'],
      };

      // Extract bank info
      const bankInfo = this.extractBankInfo(result.data.merchantAccount);
      result.data.bank = bankInfo;

      result.isValid = true;

    } catch (error) {
      console.error('EMV QR Parse Error:', error);
    }

    return result;
  }

  /**
   * Parse Merchant Account fields (26-51)
   */
  static parseMerchantAccount(fields) {
    const merchantAccounts = [];

    // Merchant account info ຢູ່ໃນ tags 26-51
    for (let i = 26; i <= 51; i++) {
      const tag = i.toString().padStart(2, '0');
      if (fields[tag]) {
        const parsed = this.parseSubfields(fields[tag]);
        merchantAccounts.push({
          tag,
          raw: fields[tag],
          parsed,
        });
      }
    }

    // Also check tag 38 specifically (common for Lao banks)
    if (fields['38']) {
      const parsed = this.parseSubfields(fields['38']);
      merchantAccounts.push({
        tag: '38',
        raw: fields['38'],
        parsed,
      });
    }

    return merchantAccounts;
  }

  /**
   * Parse subfields within a TLV field
   */
  static parseSubfields(data) {
    const subfields = {};
    let pos = 0;

    try {
      while (pos < data.length - 4) {
        const subTag = data.substring(pos, pos + 2);
        const subLength = parseInt(data.substring(pos + 2, pos + 4), 10);
        
        if (isNaN(subLength) || subLength <= 0) break;
        
        const subValue = data.substring(pos + 4, pos + 4 + subLength);
        subfields[subTag] = subValue;
        pos += 4 + subLength;
      }
    } catch (e) {
      // Ignore parse errors in subfields
    }

    return subfields;
  }

  /**
   * Extract bank information from merchant accounts
   */
  static extractBankInfo(merchantAccounts) {
    const bankInfo = {
      bankCode: null,
      bankName: null,
      accountNumber: null,
      merchantId: null,
    };

    for (const account of merchantAccounts) {
      const parsed = account.parsed || {};
      
      // Common subfield mappings:
      // 00: Globally Unique Identifier (contains bank code)
      // 01: Merchant Account Number
      // 02: Merchant ID
      // 03: Additional data

      if (parsed['00']) {
        // GUID contains bank identifier
        const guid = parsed['00'];
        
        // Detect bank from GUID
        if (guid.includes('BCEL') || guid.includes('bcel')) {
          bankInfo.bankCode = 'BCEL';
          bankInfo.bankName = 'BCEL';
        } else if (guid.includes('JDB') || guid.includes('jdb')) {
          bankInfo.bankCode = 'JDB';
          bankInfo.bankName = 'JDB';
        } else if (guid.includes('LDB') || guid.includes('ldb')) {
          bankInfo.bankCode = 'LDB';
          bankInfo.bankName = 'LDB';
        } else if (guid.includes('APB') || guid.includes('apb')) {
          bankInfo.bankCode = 'APB';
          bankInfo.bankName = 'APB';
        }
      }

      if (parsed['01']) {
        bankInfo.accountNumber = parsed['01'];
      }
      if (parsed['02']) {
        bankInfo.merchantId = parsed['02'];
      }
    }

    return bankInfo;
  }

  /**
   * ກວດວ່າ string ແມ່ນ EMV QR ບໍ
   */
  static isEMVQR(qrString) {
    return qrString && qrString.startsWith('000201');
  }

  /**
   * ກວດວ່າ string ແມ່ນ Lightning Invoice ບໍ
   */
  static isLightningInvoice(str) {
    if (!str) return false;
    let lower = str.toLowerCase();
    
    // ເອົາ prefix "lightning:" ອອກ (ຖ້າມີ)
    if (lower.startsWith('lightning:')) {
      lower = lower.substring(10);
    }
    
    return lower.startsWith('lnbc') || lower.startsWith('lntb') || lower.startsWith('lnurl');
  }

  /**
   * ເອົາ Lightning Invoice ທີ່ສະອາດ (ບໍ່ມີ prefix)
   */
  static cleanLightningInvoice(str) {
    if (!str) return str;
    let cleaned = str;
    
    // ເອົາ prefix "lightning:" ອອກ
    if (cleaned.toLowerCase().startsWith('lightning:')) {
      cleaned = cleaned.substring(10);
    }
    
    return cleaned;
  }

  /**
   * ກວດປະເພດ QR/ID
   */
  static detectType(str) {
    if (!str) return 'unknown';
    
    // ເອົາ prefix ອອກກ່ອນກວດ
    let cleanStr = str;
    if (cleanStr.toLowerCase().startsWith('lightning:')) {
      cleanStr = cleanStr.substring(10);
    }
    
    if (this.isLightningInvoice(cleanStr)) {
      return 'lightning_invoice';
    }
    
    if (this.isEMVQR(str)) {
      return 'emv_qr';
    }
    
    // ກວດວ່າເປັນ Sabaidee Merchant QR ບໍ
    if (str.startsWith('QR_') || str.startsWith('MER')) {
      return 'sabaidee_merchant';
    }
    
    // ອາດເປັນ wallet ID
    return 'wallet_id';
  }
}

module.exports = EMVQRParser;