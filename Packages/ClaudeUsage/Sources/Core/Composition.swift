//
//  Composition.swift
//  ClaudeUsageCore
//
//  Forward function composition operators
//

// MARK: - Operator Declarations

/// Forward composition operator: applies left function, then right function
infix operator >>>: FunctionCompositionPrecedence

/// Backward composition operator: applies right function, then left function
infix operator <<<: FunctionCompositionPrecedence

/// Precedence for function composition - lower than most operators
precedencegroup FunctionCompositionPrecedence {
    associativity: left
    higherThan: AssignmentPrecedence
}

// MARK: - Forward Composition

/// Forward composition: `f >>> g` means "first f, then g"
/// Enables building pipelines: `validate >>> transform >>> format`
public func >>> <A, B, C>(
    _ f: @escaping @Sendable (A) -> B,
    _ g: @escaping @Sendable (B) -> C
) -> @Sendable (A) -> C {
    { a in g(f(a)) }
}

/// Forward composition for optional-returning functions
/// Chains functions where the first may return nil
public func >>> <A, B, C>(
    _ f: @escaping @Sendable (A) -> B?,
    _ g: @escaping @Sendable (B) -> C
) -> @Sendable (A) -> C? {
    { a in f(a).map(g) }
}

// MARK: - Backward Composition

/// Backward composition: `f <<< g` means "first g, then f"
public func <<< <A, B, C>(
    _ f: @escaping @Sendable (B) -> C,
    _ g: @escaping @Sendable (A) -> B
) -> @Sendable (A) -> C {
    { a in f(g(a)) }
}
