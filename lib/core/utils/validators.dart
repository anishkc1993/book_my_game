class Validators {
  static const int phoneNumberLength = 10;

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length != phoneNumberLength) {
      return 'Phone number must be exactly $phoneNumberLength digits';
    }

    return null;
  }

  /// Check if phone number is valid (10 digits)
  static bool isValidPhoneNumber(String? value) {
    if (value == null || value.isEmpty) return false;
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length == phoneNumberLength;
  }

  static String? validateOtp(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }

    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return 'OTP must contain only numbers';
    }

    return null;
  }

  static String formatPhoneNumber(String phoneNumber, {String countryCode = '+1'}) {
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.startsWith('0')) {
      return '$countryCode${digitsOnly.substring(1)}';
    }

    if (!phoneNumber.startsWith('+')) {
      return '$countryCode$digitsOnly';
    }

    return phoneNumber;
  }
}
