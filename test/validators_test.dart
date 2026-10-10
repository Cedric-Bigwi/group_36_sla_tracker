import 'package:flutter_test/flutter_test.dart';
import 'package:on_track/core/utils/validators.dart';

void main() {
  final now = DateTime.utc(2026, 3, 10, 12);

  group('title', () {
    test('required', () {
      expect(Validators.title(null), isNotNull);
      expect(Validators.title(''), isNotNull);
      expect(Validators.title('    '), isNotNull);
    });
    test('length bounds are applied to the trimmed value', () {
      expect(Validators.title('ab'), isNotNull);
      expect(Validators.title('  ab  '), isNotNull);
      expect(Validators.title('abc'), isNull);
      expect(Validators.title('a' * 80), isNull);
      expect(Validators.title('a' * 81), isNotNull);
    });
  });

  group('description', () {
    test('optional but capped at 500', () {
      expect(Validators.description(null), isNull);
      expect(Validators.description('a' * 500), isNull);
      expect(Validators.description('a' * 501), isNotNull);
    });
  });

  group('dates', () {
    test('due before start is rejected', () {
      final start = now.add(const Duration(days: 2));
      final due = now.add(const Duration(days: 1));
      expect(
        Validators.dueDate(start: start, due: due, now: now, isNew: true),
        contains('before the start'),
      );
    });
    test('due equal to start is allowed', () {
      final d = now.add(const Duration(days: 1));
      expect(Validators.dueDate(start: d, due: d, now: now, isNew: true), isNull);
    });
    test('new task cannot be due in the past', () {
      final due = now.subtract(const Duration(minutes: 1));
      expect(
        Validators.dueDate(
          start: now.subtract(const Duration(days: 1)),
          due: due,
          now: now,
          isNew: true,
        ),
        contains('past'),
      );
    });
    test('existing task may be due in the past (UI shows a warning)', () {
      final due = now.subtract(const Duration(minutes: 1));
      expect(
        Validators.dueDate(
          start: now.subtract(const Duration(days: 1)),
          due: due,
          now: now,
          isNew: false,
        ),
        isNull,
      );
    });
    test('missing due date', () {
      expect(
        Validators.dueDate(start: now, due: null, now: now, isNew: true),
        isNotNull,
      );
    });
  });

  group('pin', () {
    test('must be exactly four digits', () {
      expect(Validators.pin(''), isNotNull);
      expect(Validators.pin('123'), isNotNull);
      expect(Validators.pin('12345'), isNotNull);
      expect(Validators.pin('12a4'), isNotNull);
      expect(Validators.pin('1234'), isNull);
    });
    test('confirmation must match', () {
      expect(Validators.confirmPin('1234', '1234'), isNull);
      expect(Validators.confirmPin('1235', '1234'), 'PINs do not match');
      expect(Validators.confirmPin('12', '1234'), isNotNull);
    });
  });

  group('email', () {
    test('basic format', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('nope'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });
  });
}
