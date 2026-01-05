//
//  MessageValidation.swift
//  Validation rules for JSONL message types
//

import Foundation

// MARK: - Message Type Validation Protocol

/// Protocol defining message type validation behavior.
/// Conform to this protocol to add support for new message types.
public protocol MessageTypeValidator: Sendable {
    /// The message type this validator handles (e.g., "assistant", "user")
    var messageType: String { get }

    /// Validates the raw data and extracts validated components
    func validate(_ raw: RawJSONLData) -> ValidatedData?
}

// MARK: - Message Type Validator Registry

/// Registry of message type validators.
/// Open for extension: register new validators at app startup.
public final class MessageTypeValidatorRegistry: @unchecked Sendable {
    public static let shared = MessageTypeValidatorRegistry()

    private var validators: [MessageTypeValidator] = [
        AssistantMessageValidator()
    ]

    private init() {}

    /// Register a new validator for a message type
    public func register(_ validator: MessageTypeValidator) {
        validators.append(validator)
    }

    /// Finds and applies the appropriate validator for the given data
    public func validate(_ raw: RawJSONLData) -> ValidatedData? {
        guard let type = raw.type else { return nil }
        return validators.first { $0.messageType == type }?.validate(raw)
    }
}

// MARK: - Composed Validation Function

/// Composable validation function using the shared registry
public let validateMessageType: @Sendable (RawJSONLData) -> ValidatedData? = { raw in
    MessageTypeValidatorRegistry.shared.validate(raw)
}

// MARK: - Assistant Message Validator

/// Validator for assistant-type messages containing usage data
public struct AssistantMessageValidator: MessageTypeValidator {
    public let messageType = "assistant"

    public init() {}

    public func validate(_ raw: RawJSONLData) -> ValidatedData? {
        guard raw.type == messageType,
              let message = raw.message,
              let usage = message.usage,
              let timestampStr = raw.timestamp else {
            return nil
        }
        return ValidatedData(message: message, usage: usage, timestampStr: timestampStr)
    }
}

// MARK: - Validated Data

public struct ValidatedData: Sendable {
    public let message: RawJSONLData.Message
    public let usage: RawJSONLData.Message.Usage
    public let timestampStr: String

    public init(message: RawJSONLData.Message, usage: RawJSONLData.Message.Usage, timestampStr: String) {
        self.message = message
        self.usage = usage
        self.timestampStr = timestampStr
    }
}
