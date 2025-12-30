# Makefile for ClaudeCodeUsage
# Provides convenient commands for development

.PHONY: help build test test-core test-data test-ui coverage clean format lint docs

# Default target
help:
	@echo "ClaudeCodeUsage Development Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  make build     - Build the project"
	@echo "  make test      - Run all tests"
	@echo "  make coverage  - Generate code coverage report"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make format    - Format code with swift-format"
	@echo "  make lint      - Lint code with SwiftLint"
	@echo "  make docs      - Generate documentation"
	@echo "  make benchmark - Run performance benchmarks"
	@echo "  make app       - Run the menu bar app"
	@echo "  make cli       - Run the CLI dashboard"

# Build the project
build:
	swift build

# Run all tests
test: test-core test-data test-ui

test-core:
	swift test --package-path Packages/ClaudeUsageCore

test-data:
	swift test --package-path Packages/ClaudeUsageData

test-ui:
	swift test --package-path Packages/ClaudeUsageUI

# Generate code coverage report
coverage:
	@./Scripts/coverage.sh

# Generate HTML coverage report
coverage-html:
	@./Scripts/coverage.sh --html

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build
	rm -f coverage.lcov

# Format code (requires swift-format)
format:
	@if command -v swift-format &> /dev/null; then \
		swift-format -i -r Sources Tests; \
	else \
		echo "⚠️  swift-format not installed. Install with: brew install swift-format"; \
	fi

# Lint code (requires SwiftLint)
lint:
	@if command -v swiftlint &> /dev/null; then \
		swiftlint; \
	else \
		echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"; \
	fi

# Generate documentation (requires docc)
docs:
	swift package generate-documentation \
		--target ClaudeCodeUsage \
		--output-path .build/docs

# Run performance benchmarks
benchmark:
	swift test --filter FileProcessingBenchmarksTests

# Run the menu bar app
app:
	swift run ClaudeCodeUsage

# Run the CLI dashboard
cli:
	swift run UsageDashboardCLI

# Run simple CLI example
simple:
	swift run SimpleCLI

# Development build with strict concurrency checking
dev:
	swift build -Xswiftc -strict-concurrency=complete

# Release build
release:
	swift build -c release

# Install the app locally
install: release
	cp .build/release/ClaudeCodeUsage /usr/local/bin/claude-usage-app
	cp .build/release/UsageDashboardCLI /usr/local/bin/claude-usage-cli
	@echo "✅ Installed to /usr/local/bin/"

# Uninstall the app
uninstall:
	rm -f /usr/local/bin/claude-usage-app
	rm -f /usr/local/bin/claude-usage-cli
	@echo "✅ Uninstalled from /usr/local/bin/"
