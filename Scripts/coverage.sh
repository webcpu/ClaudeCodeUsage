#!/bin/bash

# Code Coverage Report Generator for ClaudeCodeUsage
# This script builds the project with coverage enabled, runs tests, and generates a coverage report

set -e

echo "🧪 Generating Code Coverage Report..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean previous build
echo "🧹 Cleaning previous builds..."
swift package clean

# Build with coverage enabled
echo "🔨 Building with coverage enabled..."
swift build --enable-code-coverage

# Run tests with coverage
echo "🏃 Running tests with coverage..."
swift test --enable-code-coverage --parallel

# Find the coverage data
COVERAGE_DIR=$(swift test --show-codecov-path | head -1 | sed 's/.*: //')
BINARY_PATH=".build/debug/ClaudeCodeUsagePackageTests.xctest/Contents/MacOS/ClaudeCodeUsagePackageTests"

# Check if xcrun and llvm-cov are available
if command -v xcrun &> /dev/null && xcrun --find llvm-cov &> /dev/null; then
    echo "📊 Generating coverage report..."
    
    # Generate JSON report
    xcrun llvm-cov export \
        -format="lcov" \
        -instr-profile="$COVERAGE_DIR" \
        "$BINARY_PATH" \
        > coverage.lcov 2>/dev/null || true
    
    # Generate human-readable report
    echo ""
    echo "📈 Coverage Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    xcrun llvm-cov report \
        -instr-profile="$COVERAGE_DIR" \
        "$BINARY_PATH" \
        -ignore-filename-regex=".*Tests.*|.*Mocks.*|.*\.generated\.swift" || true
    
    # Generate detailed HTML report (optional)
    if [ "$1" == "--html" ]; then
        echo ""
        echo "🌐 Generating HTML report..."
        xcrun llvm-cov show \
            -format=html \
            -instr-profile="$COVERAGE_DIR" \
            "$BINARY_PATH" \
            -output-dir=.build/coverage-html \
            -ignore-filename-regex=".*Tests.*|.*Mocks.*"
        
        echo "✅ HTML report generated at: .build/coverage-html/index.html"
        
        # Open in browser on macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open .build/coverage-html/index.html
        fi
    fi
    
    echo ""
    echo "✅ Coverage report complete!"
    
    # Parse and display coverage percentage
    COVERAGE=$(xcrun llvm-cov report \
        -instr-profile="$COVERAGE_DIR" \
        "$BINARY_PATH" \
        -ignore-filename-regex=".*Tests.*|.*Mocks.*" 2>/dev/null | \
        tail -1 | \
        awk '{print $NF}')
    
    echo ""
    echo "🎯 Total Coverage: $COVERAGE"
    
    # Check if coverage meets threshold
    THRESHOLD=80
    COVERAGE_NUM=$(echo $COVERAGE | sed 's/%//')
    
    if (( $(echo "$COVERAGE_NUM >= $THRESHOLD" | bc -l) )); then
        echo "✅ Coverage meets threshold of $THRESHOLD%"
    else
        echo "⚠️  Coverage below threshold of $THRESHOLD%"
        echo "   Consider adding more tests to improve coverage."
    fi
    
else
    echo "⚠️  llvm-cov not found. Install Xcode command line tools."
    echo "   Run: xcode-select --install"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Tips:"
echo "   • Run with --html flag to generate HTML report"
echo "   • Coverage data saved to: coverage.lcov"
echo "   • Integrate with CI/CD for automated coverage tracking"