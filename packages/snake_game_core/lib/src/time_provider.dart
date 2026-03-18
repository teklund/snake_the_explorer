/// Abstraction over time for testability.
/// In production, use [SystemTimeProvider]. In tests, inject a mock.
abstract interface class TimeProvider {
  DateTime now();
}

/// Default implementation that delegates to [DateTime.now].
final class SystemTimeProvider implements TimeProvider {
  const SystemTimeProvider();

  @override
  DateTime now() => DateTime.now();
}
