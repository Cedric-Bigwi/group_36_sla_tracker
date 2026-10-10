/// Injectable time source. Everything that depends on "now" receives a
/// [Clock] (or a plain [DateTime]) so tests can freeze time.
typedef Clock = DateTime Function();

/// Production clock. Returns a UTC instant; convert with `.toLocal()` only
/// when formatting for display.
DateTime systemClock() => DateTime.now().toUtc();
