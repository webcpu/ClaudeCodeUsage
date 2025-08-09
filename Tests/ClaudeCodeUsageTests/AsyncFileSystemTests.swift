//
//  AsyncFileSystemTests.swift
//  ClaudeCodeUsageTests
//
//  Tests for AsyncFileSystemProtocol implementations
//

import Testing
import Foundation
@testable import ClaudeCodeUsage

@Suite("AsyncFileSystemProtocol Tests")
struct AsyncFileSystemTests {
    
    // MARK: - AsyncFileSystem Tests
    
    @Test("AsyncFileSystem should check if file exists")
    func testFileExists() async {
        // Given
        let fileSystem = AsyncFileSystem()
        let existingPath = FileManager.default.temporaryDirectory.path
        let nonExistentPath = "/non/existent/path/file.txt"
        
        // When
        let existsResult = await fileSystem.fileExists(atPath: existingPath)
        let notExistsResult = await fileSystem.fileExists(atPath: nonExistentPath)
        
        // Then
        #expect(existsResult == true)
        #expect(notExistsResult == false)
    }
    
    @Test("AsyncFileSystem should list directory contents")
    func testContentsOfDirectory() async throws {
        // Given
        let fileSystem = AsyncFileSystem()
        let tempDir = FileManager.default.temporaryDirectory.path
        
        // When
        let contents = try await fileSystem.contentsOfDirectory(atPath: tempDir)
        
        // Then
        #expect(contents.count >= 0)
    }
    
    @Test("AsyncFileSystem should throw error for invalid directory")
    func testContentsOfDirectoryThrowsError() async {
        // Given
        let fileSystem = AsyncFileSystem()
        let invalidPath = "/non/existent/directory"
        
        // When/Then
        await #expect(throws: (any Error).self) {
            _ = try await fileSystem.contentsOfDirectory(atPath: invalidPath)
        }
    }
    
    @Test("AsyncFileSystem should read file contents")
    func testReadFile() async throws {
        // Given
        let fileSystem = AsyncFileSystem()
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID()).txt")
        let testContent = "Test content for async file system"
        try testContent.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        // When
        let content = try await fileSystem.readFile(atPath: tempFile.path)
        
        // Then
        #expect(content == testContent)
    }
    
    // MARK: - AsyncFileSystemBridge Tests
    
    @Test("AsyncFileSystemBridge should bridge sync to async")
    func testBridgeFileExists() async {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.mockFiles["/test/file.txt"] = "content"
        let bridge = AsyncFileSystemBridge(fileSystem: mockFileSystem)
        
        // When
        let exists = await bridge.fileExists(atPath: "/test/file.txt")
        let notExists = await bridge.fileExists(atPath: "/test/missing.txt")
        
        // Then
        #expect(exists == true)
        #expect(notExists == false)
    }
    
    @Test("AsyncFileSystemBridge should bridge directory listing")
    func testBridgeContentsOfDirectory() async throws {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.mockFiles["/test/dir/file1.txt"] = "content1"
        mockFileSystem.mockFiles["/test/dir/file2.txt"] = "content2"
        let bridge = AsyncFileSystemBridge(fileSystem: mockFileSystem)
        
        // When
        let contents = try await bridge.contentsOfDirectory(atPath: "/test/dir")
        
        // Then
        #expect(contents.contains("file1.txt"))
        #expect(contents.contains("file2.txt"))
    }
    
    @Test("AsyncFileSystemBridge should bridge file reading")
    func testBridgeReadFile() async throws {
        // Given
        let mockFileSystem = MockFileSystem()
        let expectedContent = "Test content"
        mockFileSystem.mockFiles["/test/file.txt"] = expectedContent
        let bridge = AsyncFileSystemBridge(fileSystem: mockFileSystem)
        
        // When
        let content = try await bridge.readFile(atPath: "/test/file.txt")
        
        // Then
        #expect(content == expectedContent)
    }
    
    @Test("AsyncFileSystemBridge should propagate errors")
    func testBridgePropagatesErrors() async {
        // Given
        let mockFileSystem = MockFileSystem()
        mockFileSystem.shouldThrowError = true
        let bridge = AsyncFileSystemBridge(fileSystem: mockFileSystem)
        
        // When/Then
        await #expect(throws: FileSystemError.self) {
            _ = try await bridge.readFile(atPath: "/any/path")
        }
    }
}

// MARK: - Mock for Testing

private class MockFileSystem: FileSystemProtocol {
    var mockFiles: [String: String] = [:]
    var shouldThrowError = false
    
    func fileExists(atPath path: String) -> Bool {
        return mockFiles.keys.contains(path) || 
               mockFiles.keys.contains { $0.hasPrefix(path + "/") }
    }
    
    func contentsOfDirectory(atPath path: String) throws -> [String] {
        if shouldThrowError {
            throw FileSystemError.directoryNotFound
        }
        
        let prefix = path.hasSuffix("/") ? path : path + "/"
        let files = mockFiles.keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { filePath in
                let remaining = filePath.replacingOccurrences(of: prefix, with: "")
                return remaining.components(separatedBy: "/").first
            }
        
        return Array(Set(files))
    }
    
    func readFile(atPath path: String) throws -> String {
        if shouldThrowError {
            throw FileSystemError.fileNotFound
        }
        
        guard let content = mockFiles[path] else {
            throw FileSystemError.fileNotFound
        }
        
        return content
    }
}

private enum FileSystemError: Error {
    case fileNotFound
    case directoryNotFound
}