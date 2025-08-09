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
}