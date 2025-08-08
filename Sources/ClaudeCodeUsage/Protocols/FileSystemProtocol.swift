//
//  FileSystemProtocol.swift
//  ClaudeCodeUsage
//
//  Protocol for file system operations (Dependency Inversion Principle)
//

import Foundation

/// Protocol for file system operations - abstracts file I/O
public protocol FileSystemProtocol {
    /// Check if a file or directory exists at the given path
    func fileExists(atPath path: String) -> Bool
    
    /// Get contents of a directory
    func contentsOfDirectory(atPath path: String) throws -> [String]
    
    /// Read file contents as string
    func readFile(atPath path: String) throws -> String
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
}

/// Mock implementation for testing
public struct MockFileSystem: FileSystemProtocol {
    public var files: [String: String]
    public var directories: [String: [String]]
    
    public init(files: [String: String] = [:], directories: [String: [String]] = [:]) {
        self.files = files
        self.directories = directories
    }
    
    public func fileExists(atPath path: String) -> Bool {
        return files[path] != nil || directories[path] != nil
    }
    
    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        guard let contents = directories[path] else {
            throw UsageClientError.fileNotFound
        }
        return contents
    }
    
    public func readFile(atPath path: String) throws -> String {
        guard let content = files[path] else {
            throw UsageClientError.fileNotFound
        }
        return content
    }
}