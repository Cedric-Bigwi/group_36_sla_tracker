import 'dart:convert';

import 'package:crypto/crypto.dart';

/// SHA-256 of `memberId:pin`.
///
/// Why include the member id? Without it two people with the same PIN would
/// have identical hashes, and a 4-digit PIN could be reversed with a 10,000
/// entry lookup table shared by all users. Using the id as a salt makes the
/// table per-user. This is local demo auth, not a replacement for a real
/// backend, and we say so in the README.
String hashPin(String memberId, String pin) =>
    sha256.convert(utf8.encode('$memberId:$pin')).toString();
