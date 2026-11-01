import 'dart:ffi';

String getPlatformAbi() {
  try {
    return Abi.current().toString().toLowerCase();
  } catch (_) {
    return '';
  }
}
