/// Pure form validators: each returns an error message, or null when valid.
/// They are plain functions so they can be unit-tested without any widgets.
abstract final class Validators {
  static const int titleMin = 3;
  static const int titleMax = 80;
  static const int descriptionMax = 500;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _pin = RegExp(r'^\d{4}$');

  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Title is required';
    if (v.length < titleMin) {
      return 'Title must be at least $titleMin characters';
    }
    if (v.length > titleMax) {
      return 'Title must be at most $titleMax characters';
    }
    return null;
  }

  static String? description(String? value) {
    if ((value ?? '').length > descriptionMax) {
      return 'Description must be at most $descriptionMax characters';
    }
    return null;
  }

  static String? required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label is required' : null;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Name is too short';
    if (v.length > 60) return 'Name is too long';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? pin(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'PIN is required';
    if (!_pin.hasMatch(v)) return 'PIN must be exactly 4 digits';
    return null;
  }

  static String? confirmPin(String? value, String? original) {
    final basic = pin(value);
    if (basic != null) return basic;
    if (value != original) return 'PINs do not match';
    return null;
  }

  /// Due date rules from the spec:
  ///  * due must be on/after start
  ///  * for NEW tasks due must not be in the past
  /// (Editing a task into the past is allowed but confirmed by a dialog in the
  /// UI, so it is not an error here.)
  static String? dueDate({
    required DateTime? start,
    required DateTime? due,
    required DateTime now,
    required bool isNew,
  }) {
    if (due == null) return 'Due date is required';
    if (start != null && due.isBefore(start)) {
      return 'Due date must not be before the start date';
    }
    if (isNew && due.isBefore(now)) {
      return 'Due date cannot be in the past';
    }
    return null;
  }

  static String? startDate(DateTime? start) =>
      start == null ? 'Start date is required' : null;
}
