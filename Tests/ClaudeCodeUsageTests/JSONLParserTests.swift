//
//  JSONLParserTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for JSONL parsing of different file formats
//

import Testing
import Foundation
@testable import ClaudeCodeUsageKit

@Suite("JSONL Parser Tests")
struct JSONLParserTests {

    let parser = JSONLUsageParser()
    let projectPath = "/Users/test/project"

    // MARK: - Valid Claude Code Format Tests

    @Test("Should parse valid Claude Code usage entry with message.usage")
    func testParseValidClaudeCodeEntry() throws {
        // Given - Valid Claude Code JSONL format
        let validLine = """
        {"parentUuid":"6e4c8134-cffe-4cae-b916-33d8fbb7d6c7","sessionId":"d6432cc6-1c2e-456a-b1c7-4adc4598fcf9","version":"2.0.76","type":"assistant","message":{"model":"claude-opus-4-5-20251101","id":"msg_012dEfkcg5NnwmS4USDAtykL","type":"message","role":"assistant","content":[{"type":"text","text":"Test response"}],"usage":{"input_tokens":2888,"cache_creation_input_tokens":100,"cache_read_input_tokens":50,"output_tokens":26}},"requestId":"req_011CWREcFR9RA2yfbWRHbekg","timestamp":"2025-12-24T08:58:03.168Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(validLine, projectPath: projectPath)

        // Then
        #expect(entry != nil)
        #expect(entry?.model == "claude-opus-4-5-20251101")
        #expect(entry?.inputTokens == 2888)
        #expect(entry?.outputTokens == 26)
        #expect(entry?.cacheWriteTokens == 100)
        #expect(entry?.cacheReadTokens == 50)
        #expect(entry?.project == projectPath)
        #expect(entry?.timestamp == "2025-12-24T08:58:03.168Z")
    }

    @Test("Should parse entry with costUSD field")
    func testParseEntryWithCostUSD() throws {
        // Given - Entry with pre-calculated cost
        let lineWithCost = """
        {"costUSD":0.05,"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"output_tokens":500}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(lineWithCost, projectPath: projectPath)

        // Then
        #expect(entry != nil)
        #expect(entry?.cost == 0.05)
    }

    @Test("Should calculate cost when costUSD is missing")
    func testCalculateCostWhenMissing() throws {
        // Given - Entry without costUSD (cost should be calculated from tokens)
        let lineWithoutCost = """
        {"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"output_tokens":500}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(lineWithoutCost, projectPath: projectPath)

        // Then
        #expect(entry != nil)
        #expect(entry!.cost > 0) // Cost should be calculated from pricing
    }

    // MARK: - RPLY App Format Tests (Should Be Skipped)

    @Test("Should skip RPLY app session files (no message.usage)")
    func testSkipRPLYSessionFormat() throws {
        // Given - RPLY app format (has message but no usage field)
        let rplyLine = """
        {"parentUuid":null,"isSidechain":true,"userType":"external","cwd":"/Users/test/project","sessionId":"c2084654-1ac5-4438-a901-9a48e0bb5427","version":"2.0.76","type":"user","message":{"role":"user","content":"Warmup"},"uuid":"94a8272c-2a55-4d21-8964-5d7cda208778","timestamp":"2025-12-23T19:40:11.290Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(rplyLine, projectPath: projectPath)

        // Then - Should return nil (skip), not throw error
        #expect(entry == nil)
    }

    @Test("Should skip user messages (no usage data)")
    func testSkipUserMessages() throws {
        // Given - User message (has message but it's a user message, no usage)
        let userMessage = """
        {"type":"user","message":{"role":"user","content":"Hello world"},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(userMessage, projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    @Test("Should skip assistant messages without usage")
    func testSkipAssistantMessagesWithoutUsage() throws {
        // Given - Assistant message without usage field
        let assistantNoUsage = """
        {"type":"assistant","message":{"role":"assistant","content":"Hello!","model":"claude-sonnet-4-20250514"},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(assistantNoUsage, projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    // MARK: - Zero Token Tests

    @Test("Should skip entries with all zero tokens")
    func testSkipZeroTokenEntries() throws {
        // Given - Entry with zero tokens (shouldn't count as usage)
        let zeroTokens = """
        {"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(zeroTokens, projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    @Test("Should parse entries with only input tokens")
    func testParseOnlyInputTokens() throws {
        // Given
        let inputOnly = """
        {"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":1000,"output_tokens":0}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(inputOnly, projectPath: projectPath)

        // Then
        #expect(entry != nil)
        #expect(entry?.inputTokens == 1000)
    }

    @Test("Should parse entries with only cache tokens")
    func testParseOnlyCacheTokens() throws {
        // Given
        let cacheOnly = """
        {"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":0,"output_tokens":0,"cache_creation_input_tokens":500}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(cacheOnly, projectPath: projectPath)

        // Then
        #expect(entry != nil)
        #expect(entry?.cacheWriteTokens == 500)
    }

    // MARK: - Error Handling Tests

    @Test("Should handle empty lines gracefully")
    func testHandleEmptyLines() throws {
        // When
        let entry = try parser.parseJSONLLine("", projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    @Test("Should handle whitespace-only lines gracefully")
    func testHandleWhitespaceLines() throws {
        // When
        let entry = try parser.parseJSONLLine("   \t  ", projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    @Test("Should handle invalid JSON gracefully")
    func testHandleInvalidJSON() throws {
        // Given - Malformed JSON
        let invalidJSON = "{not valid json"

        // When
        let entry = try parser.parseJSONLLine(invalidJSON, projectPath: projectPath)

        // Then - Should return nil, not throw
        #expect(entry == nil)
    }

    @Test("Should handle partial/truncated JSON gracefully")
    func testHandleTruncatedJSON() throws {
        // Given - Truncated JSON (file write interrupted)
        let truncated = """
        {"message":{"model":"claude-sonnet-4-20250514","usage":{"input_tokens":100
        """

        // When
        let entry = try parser.parseJSONLLine(truncated, projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    @Test("Should handle JSON array instead of object")
    func testHandleJSONArray() throws {
        // Given - Valid JSON but array, not object
        let jsonArray = "[1, 2, 3]"

        // When
        let entry = try parser.parseJSONLLine(jsonArray, projectPath: projectPath)

        // Then
        #expect(entry == nil)
    }

    // MARK: - Extraction Tests

    @Test("Should extract message ID for deduplication")
    func testExtractMessageId() {
        // Given
        let json: [String: Any] = [
            "message": [
                "id": "msg_123abc",
                "model": "claude-sonnet-4-20250514"
            ]
        ]

        // When
        let messageId = parser.extractMessageId(from: json)

        // Then
        #expect(messageId == "msg_123abc")
    }

    @Test("Should extract request ID for deduplication")
    func testExtractRequestId() {
        // Given
        let json: [String: Any] = [
            "requestId": "req_456def"
        ]

        // When
        let requestId = parser.extractRequestId(from: json)

        // Then
        #expect(requestId == "req_456def")
    }

    @Test("Should extract timestamp for sorting")
    func testExtractTimestamp() {
        // Given
        let json: [String: Any] = [
            "timestamp": "2025-12-24T10:00:00.000Z"
        ]

        // When
        let timestamp = parser.extractTimestamp(from: json)

        // Then
        #expect(timestamp == "2025-12-24T10:00:00.000Z")
    }

    @Test("Should return nil for missing extraction fields")
    func testMissingExtractionFields() {
        // Given - Empty JSON
        let emptyJson: [String: Any] = [:]

        // When
        let messageId = parser.extractMessageId(from: emptyJson)
        let requestId = parser.extractRequestId(from: emptyJson)
        let timestamp = parser.extractTimestamp(from: emptyJson)

        // Then
        #expect(messageId == nil)
        #expect(requestId == nil)
        #expect(timestamp == nil)
    }

    // MARK: - Model Handling Tests

    @Test("Should use 'unknown' for missing model")
    func testUnknownModelFallback() throws {
        // Given - Valid usage but no model specified
        let noModel = """
        {"message":{"usage":{"input_tokens":100,"output_tokens":50}},"timestamp":"2025-12-24T10:00:00.000Z"}
        """

        // When
        let entry = try parser.parseJSONLLine(noModel, projectPath: projectPath)

        // Then
        #expect(entry?.model == "unknown")
    }

    @Test("Should parse various Claude model names")
    func testVariousModelNames() throws {
        let models = [
            "claude-opus-4-5-20251101",
            "claude-sonnet-4-20250514",
            "claude-haiku-4-5-20251001",
            "claude-3-opus-20240229",
            "claude-3-5-sonnet-20241022"
        ]

        for model in models {
            let line = """
            {"message":{"model":"\(model)","usage":{"input_tokens":100,"output_tokens":50}},"timestamp":"2025-12-24T10:00:00.000Z"}
            """

            let entry = try parser.parseJSONLLine(line, projectPath: projectPath)

            #expect(entry?.model == model, "Model \(model) should be parsed correctly")
        }
    }
}
