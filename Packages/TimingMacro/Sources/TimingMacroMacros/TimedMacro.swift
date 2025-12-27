import Foundation
import SwiftCompilerPlugin
import SwiftParser
import SwiftSyntax
import SwiftSyntaxMacros

public struct TimedMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
            throw MacroError.notAFunction
        }

        guard let body = funcDecl.body else {
            throw MacroError.missingBody
        }

        let isAsync = funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil
        let isThrowing = funcDecl.signature.effectSpecifiers?.throwsClause != nil
        let returnType = funcDecl.signature.returnClause?.type.description
            .trimmingCharacters(in: .whitespaces)
        let hasReturn = returnType != nil && returnType != "Void" && returnType != "()"

        let statements = body.statements

        if hasReturn {
            return buildTimedBodyWithReturn(
                statements: statements,
                isAsync: isAsync,
                isThrowing: isThrowing
            )
        } else {
            return buildTimedBodyVoid(statements: statements)
        }
    }

    private static func buildTimedBodyVoid(
        statements: CodeBlockItemListSyntax
    ) -> [CodeBlockItemSyntax] {
        let originalBody = statements.map { $0.description }.joined()

        let code = """
            let _startTime = ContinuousClock.now
            defer {
                let _elapsed = ContinuousClock.now - _startTime
                print("[Timed] \\(#function) took \\(_elapsed)")
            }
            \(originalBody)
            """

        return parseStatements(code)
    }

    private static func buildTimedBodyWithReturn(
        statements: CodeBlockItemListSyntax,
        isAsync: Bool,
        isThrowing: Bool
    ) -> [CodeBlockItemSyntax] {
        let originalBody = statements.map { $0.description }.joined()

        let tryAwait = [
            isThrowing ? "try" : nil,
            isAsync ? "await" : nil
        ].compactMap { $0 }.joined(separator: " ")

        let prefix = tryAwait.isEmpty ? "" : "\(tryAwait) "

        let code = """
            let _startTime = ContinuousClock.now
            let _result = \(prefix){
                \(originalBody)
            }()
            let _elapsed = ContinuousClock.now - _startTime
            print("[Timed] \\(#function) took \\(_elapsed)")
            return _result
            """

        return parseStatements(code)
    }

    private static func parseStatements(_ code: String) -> [CodeBlockItemSyntax] {
        let sourceFile = Parser.parse(source: code)
        return sourceFile.statements.map { $0 }
    }
}

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

@main
struct TimingMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        TimedMacro.self
    ]
}
