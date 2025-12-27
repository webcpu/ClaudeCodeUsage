import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import TimingMacroMacros

struct TimedMacroTests {
    let testMacros: [String: Macro.Type] = [
        "Timed": TimedMacro.self
    ]

    @Test func timedVoidFunction() {
        assertMacroExpansion(
            """
            @Timed
            func doWork() {
                print("working")
            }
            """,
            expandedSource: """
            func doWork() {
                let _startTime = ContinuousClock.now
                defer {
                    let _elapsed = ContinuousClock.now - _startTime
                    print("[Timed] \\(#function) took \\(_elapsed)")
                }
                print("working")
            }
            """,
            macros: testMacros
        )
    }

    @Test func timedFunctionWithReturn() {
        assertMacroExpansion(
            """
            @Timed
            func calculate() -> Int {
                return 42
            }
            """,
            expandedSource: """
            func calculate() -> Int {
                let _startTime = ContinuousClock.now
                let _result = {
                    return 42
                }()
                let _elapsed = ContinuousClock.now - _startTime
                print("[Timed] \\(#function) took \\(_elapsed)")
                return _result
            }
            """,
            macros: testMacros
        )
    }
}
