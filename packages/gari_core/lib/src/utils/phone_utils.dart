class PhoneUtils {
  static String? normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('251') && digits.length == 12) return '+$digits';
    if (digits.startsWith('0') && digits.length == 10) {
      digits = digits.substring(1);
    }
    if (digits.length == 9 &&
        (digits.startsWith('9') || digits.startsWith('7'))) {
      return '+251$digits';
    }
    return null;
  }

  static bool isValidLocal(String raw) => normalize(raw) != null;
}
