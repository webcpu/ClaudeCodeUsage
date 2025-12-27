/// Measures and logs function execution time.
///
/// Usage:
/// ```swift
/// @Timed
/// func expensiveOperation() {
///     // ...
/// }
/// ```
///
/// Output: `[TimingMacro] expensiveOperation() took 0.123s`
@attached(body)
public macro Timed() = #externalMacro(module: "TimingMacroMacros", type: "TimedMacro")
