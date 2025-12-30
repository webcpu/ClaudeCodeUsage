# Makefile for ClaudeCodeUsage
# Provides convenient commands for development

.PHONY: help test test-core test-data test-ui clean format lint

# Default target
help:
	@echo "ClaudeCodeUsage Development Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make test      - Run all tests"
	@echo "  make test-core - Run ClaudeUsageCore tests"
	@echo "  make test-data - Run ClaudeUsageData tests"
	@echo "  make test-ui   - Run ClaudeUsageUI tests"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make format    - Format code with swift-format"
	@echo "  make lint      - Lint code with SwiftLint"

# Run all tests
test: test-core test-data test-ui

test-core:
	swift test --package-path Packages/ClaudeUsageCore

test-data:
	swift test --package-path Packages/ClaudeUsageData

test-ui:
	swift test --package-path Packages/ClaudeUsageUI

# Clean build artifacts
clean:
	rm -rf Packages/ClaudeUsageCore/.build
	rm -rf Packages/ClaudeUsageData/.build
	rm -rf Packages/ClaudeUsageUI/.build

# Format code (requires swift-format)
format:
	@if command -v swift-format &> /dev/null; then \
		swift-format -i -r Packages/*/Sources Packages/*/Tests; \
	else \
		echo "swift-format not installed. Install with: brew install swift-format"; \
	fi

# Lint code (requires SwiftLint)
lint:
	@if command -v swiftlint &> /dev/null; then \
		swiftlint; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
	fi
