const pendingEmailLinkAddressKey = 'auth.pending_email_link_address';

bool isValidEmailAddress(String value) {
  final email = value.trim();
  final separator = email.indexOf('@');
  if (separator <= 0 || separator != email.lastIndexOf('@')) return false;
  final domain = email.substring(separator + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.') &&
      !email.contains(RegExp(r'\s'));
}
