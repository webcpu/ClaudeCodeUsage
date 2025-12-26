//
//  AsyncFileSystemProtocol.swift
//  ClaudeCodeUsage
//
//  Async version of FileSystemProtocol for modern Swift concurrency
//

import Foundation

/// Async file system operations protocol
public protocol AsyncFileSystemProtocol {
    /// Check if a file or directory exists at the given path
    func fileExists(atPath path: String) async -> Bool
    
    /// Get contents of a directory
    func contentsOfDirectory(atPath path: String) async throws -> [String]
    
    /// Read file contents as string
    func readFile(atPath path: String) async throws -> String
    
    /// Read only the first line of a file (optimized for large files)
    func readFirstLine(atPath path: String) async throws -> String?
}

/// Bridge from sync to async FileSystemProtocol
public struct AsyncFileSystemBridge: AsyncFileSystemProtocol {
    private let syncFileSystem: FileSystemProtocol
    
    public init(fileSystem: FileSystemProtocol) {
        self.syncFileSystem = fileSystem
    }
    
    public func fileExists(atPath path: String) async -> Bool {
        syncFileSystem.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) async throws -> [String] {
        try syncFileSystem.contentsOfDirectory(atPath: path)
    }
    
    public func readFile(atPath path: String) async throws -> String {
        try syncFileSystem.readFile(atPath: path)
    }
    
    public func readFirstLine(atPath path: String) async throws -> String? {
        try syncFileSystem.readFirstLine(atPath: path)
    }
}

/// Default async file system implementation
public struct AsyncFileSystem: AsyncFileSystemProtocol {
    private let fileManager = FileManager.default
    
    public init() {}
    
    public func fileExists(atPath path: String) async -> Bool {
        fileManager.fileExists(atPath: path)
    }
    
    public func contentsOfDirectory(atPath path: String) async throws -> [String] {
        try fileManager.contentsOfDirectory(atPath: path)
    }
    
    public func readFile(atPath path: String) async throws -> String {
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    public func readFirstLine(atPath path: String) async throws -> String? {
        // Optimized: Use stream reading to get just the first line
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            throw FileSystemError.directoryNotFound
        }
        defer { try? fileHandle.close() }
        
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