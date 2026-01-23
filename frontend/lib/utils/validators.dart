import 'package:email_validator/email_validator.dart';

class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'ກະລຸນາປ້ອນອີເມວ';
    }
    if (!EmailValidator.validate(value)) {
      return 'ອີເມວບໍ່ຖືກຕ້ອງ';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'ກະລຸນາປ້ອນລະຫັດຜ່ານ';
    }
    if (value.length < 6) {
      return 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວອັກສອນ';
    }
    return null;
  }

  static String? validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'ກະລຸນາປ້ອນຊື່ເຕັມ';
    }
    if (value.length < 2) {
      return 'ຊື່ຕ້ອງມີຢ່າງໜ້ອຍ 2 ຕົວອັກສອນ';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'ກະລຸນາຢືນຢັນລະຫັດຜ່ານ';
    }
    if (value != password) {
      return 'ລະຫັດຜ່ານບໍ່ກົງກັນ';
    }
    return null;
  }
}