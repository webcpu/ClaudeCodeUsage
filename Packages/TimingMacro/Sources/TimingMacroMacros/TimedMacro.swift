import Foundation
import SwiftCompilerPlugin
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

// MARK: - Public API

public struct TimedMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        let funcDecl = try extractFunctionDecl(from: declaration)
        let signature = FunctionSignature(from: funcDecl)
        return buildTimedBody(for: funcDecl, signature: signature)
    }
}

// MARK: - Function Signature Extraction

private struct FunctionSignature {
    let isAsync: Bool
    let isThrowing: Bool
    let hasReturn: Bool

    init(from funcDecl: FunctionDeclSyntax) {
        let effects = funcDecl.signature.effectSpecifiers
        self.isAsync = effects?.asyncSpecifier != nil
        self.isThrowing = effects?.throwsClause != nil
        self.hasReturn = Self.detectReturn(from: funcDecl)
    }

    private static func detectReturn(from funcDecl: FunctionDeclSyntax) -> Bool {
        guard let returnType = funcDecl.signature.returnClause?.type.description
            .trimmingCharacters(in: .whitespaces) else { return false }
        return returnType != "Void" && returnType != "()"
    }

    var effectPrefix: String {
        [
            isThrowing ? "try" : nil,
            isAsync ? "await" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

// MARK: - Validation

private func extractFunctionDecl(
    from declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax
) throws -> FunctionDeclSyntax {
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
        throw MacroError.notAFunction
    }
    guard funcDecl.body != nil else {
        throw MacroError.missingBody
    }
    return funcDecl
}

// MARK: - Code Generation

private func buildTimedBody(
    for funcDecl: FunctionDeclSyntax,
    signature: FunctionSignature
) -> [CodeBlockItemSyntax] {
    let originalBody = extractBody(from: funcDecl)

    let code = signature.hasReturn
        ? CodeTemplate.withReturn(body: originalBody, effectPrefix: signature.effectPrefix)
        : CodeTemplate.voidReturn(body: originalBody)

    return parseStatements(code)
}

private func extractBody(from funcDecl: FunctionDeclSyntax) -> String {
    funcDecl.body!.statements.map(\.description).joined()
}

private func parseStatements(_ code: String) -> [CodeBlockItemSyntax] {
    Parser.parse(source: code).statements.map { $0 }
}

// MARK: - Code Templates

private enum CodeTemplate {
    static func voidReturn(body: String) -> String {
        """
        let _startTime = ContinuousClock.now
        defer {
            let _elapsed = ContinuousClock.now - _startTime
            print("[Timed] \\(#function) took \\(_elapsed)")
        }
        \(body)
        """
    }

    static func withReturn(body: String, effectPrefix: String) -> String {
        let prefix = effectPrefix.isEmpty ? "" : "\(effectPrefix) "
        return """
            let _startTime = ContinuousClock.now
            let _result = \(prefix){
                \(body)
            }()
            let _elapsed = ContinuousClock.now - _startTime
            print("[Timed] \\(#function) took \\(_elapsed)")
            return _result
            """
    }
}

// MARK: - Errors

enum MacroError: Error, CustomStringConvertible {
    case notAFunction
    case missingBody

    var description: String {
        switch self {
        case .notAFunction:
            return "@Timed can only be applied to functions"
        case .missingBody:
            return "@Timed requires a function with a body"
        }
    }
}

// MARK: - Plugin

@main
struct TimingMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TimedMacro.self
    ]
}
