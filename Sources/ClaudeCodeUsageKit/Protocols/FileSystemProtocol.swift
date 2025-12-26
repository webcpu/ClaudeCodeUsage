//
//  FileSystemProtocol.swift
//  ClaudeCodeUsage
//
//  Protocol for file system operations (Dependency Inversion Principle)
//

import Foundation

/// File system errors for dependency injection testing
public enum FileSystemError: Error, LocalizedError {
    case directoryNotFound
    case fileLocked
    case permissionDenied
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .directoryNotFound:
            return "Directory not found"
        case .fileLocked:
            return "File is locked by another process"
        case .permissionDenied:
            return "Permission denied"
        case .unknown:
            return "Unknown file system error"
        }
    }
}

/// Protocol for file system operations - abstracts file I/O
public protocol FileSystemProtocol {
    /// Check if a file or directory exists at the given path
    func fileExists(atPath path: String) -> Bool
    
    /// Get contents of a directory
    func contentsOfDirectory(atPath path: String) throws -> [String]
    
    /// Read file contents as string
    func readFile(atPath path: String) throws -> String
    
    /// Read only the first line of a file (optimized for large files)
    func readFirstLine(atPath path: String) throws -> String?
}

/// Default implementation using FileManager
public struct FileSystemService: FileSystemProtocol {
    private let fileManager: FileManager
    
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    public func fileExists(atPath path: String) -> Bool {
        return fileManager.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        return try fileManager.contentsOfDirectory(atPath: path)
    }
    
    public func readFile(atPath path: String) throws -> String {
        return try String(contentsOfFile: path, encoding: .utf8)
    }
    
    public func readFirstLine(atPath path: String) throws -> String? {
        // Optimized: Use stream reading to get just the first line
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw FileSystemError.directoryNotFound
        }
        defer { fileHandle.closeFile() }
        
        // Read up to 4KB to find the first line (should be more than enough)
        let data = fileHandle.readData(ofLength: 4096)
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Find first newline and return the line
        if let newlineRange = content.range(of: "\n") {
            return String(content[..<newlineRange.lowerBound])
        }
        
        // If no newline found, return the entire content (single line file)
        return content.isEmpty ? nil : content
    }
}

/// Enhanced mock implementation for testing with error simulation
public final class MockFileSystem: FileSystemProtocol {
    public var files: [String: String]
    public var directories: [String: [String]]
    public var shouldThrowError = false
    public var errorToThrow: Error = FileSystemError.unknown
    public var failureCount = 0
    public var attemptCount = 0
    
    public init(files: [String: String] = [:], directories: [String: [String]] = [:]) {
        self.files = files
        self.directories = directories
    }
    
    public func fileExists(atPath path: String) -> Bool {
        if shouldThrowError {
            return false
        }
        return files[path] != nil || directories[path] != nil
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        attemptCount += 1
        
        if shouldThrowError && attemptCount <= failureCount {
            throw errorToThrow
        }
        
        guard let contents = directories[path] else {
            throw FileSystemError.directoryNotFound
        }
        return contents
    }
    
    public func readFile(atPath path: String) throws -> String {
        attemptCount += 1
        
        if shouldThrowError && attemptCount <= failureCount {
            throw errorToThrow
        }
        
        guard let content = files[path] else {
            throw FileSystemError.directoryNotFound
        }
        return content
    }
    
    public func readFirstLine(atPath path: String) throws -> String? {
        guard let content = files[path] else {
            throw FileSystemError.directoryNotFound
        }
        
        // Find first newline and return the line
        if let newlineIndex = content.firstIndex(of: "\n") {
            return String(content[..<newlineIndex])
        }
        
        return content.isEmpty ? nil : content
    }
}