//
//  AdvancedAsyncStreams.swift
//  Advanced AsyncStream patterns with backpressure and throttling
//

import Foundation

// MARK: - Backpressure Strategies

/// Strategy for handling backpressure in async streams
public enum BackpressureStrategy: Sendable {
    /// Drop oldest values when buffer is full
    case dropOldest(bufferSize: Int)
    /// Drop newest values when buffer is full
    case dropNewest(bufferSize: Int)
    /// Buffer all values (may cause memory issues)
    case unbounded
    /// Block producer until consumer catches up
    case blocking(bufferSize: Int)
}

// MARK: - AsyncStream with Backpressure

/// Enhanced AsyncStream with backpressure handling
public struct BackpressureAsyncStream<Element: Sendable>: AsyncSequence {
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    
    private let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation
    
    public init(
        _ elementType: Element.Type = Element.self,
        strategy: BackpressureStrategy = .dropOldest(bufferSize: 100),
        build: @escaping (AsyncStream<Element>.Continuation) async -> Void
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        
        switch strategy {
        case .dropOldest(let bufferSize):
            self.stream = AsyncStream(bufferingPolicy: .bufferingOldest(bufferSize)) { continuation in
                localContinuation = continuation
                Task {
                    await build(continuation)
                }
            }
            
        case .dropNewest(let bufferSize):
            self.stream = AsyncStream(bufferingPolicy: .bufferingNewest(bufferSize)) { continuation in
                localContinuation = continuation
                Task {
                    await build(continuation)
                }
            }
            
        case .unbounded:
            self.stream = AsyncStream(bufferingPolicy: .unbounded) { continuation in
                localContinuation = continuation
                Task {
                    await build(continuation)
                }
            }
            
        case .blocking(let bufferSize):
            // Custom implementation for blocking strategy
            self.stream = AsyncStream { continuation in
                localContinuation = continuation
                Task {
                    await BlockingBackpressureHandler(
                        bufferSize: bufferSize,
                        continuation: continuation
                    ).run(build: build)
                }
            }
        }
        
        self.continuation = localContinuation
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
}

// MARK: - Blocking Backpressure Handler

private actor BlockingBackpressureHandler<Element: Sendable> {
    private let bufferSize: Int
    private var buffer: [Element] = []
    private let continuation: AsyncStream<Element>.Continuation
    private var waitingProducers: [CheckedContinuation<Void, Never>] = []
    
    init(bufferSize: Int, continuation: AsyncStream<Element>.Continuation) {
        self.bufferSize = bufferSize
        self.continuation = continuation
    }
    
    func run(build: @escaping (AsyncStream<Element>.Continuation) async -> Void) async {
        // Create a proxy stream to intercept yields
        let (proxyStream, proxyContinuation) = AsyncStream<Element>.makeStream()
        
        // Start consuming the proxy stream and forward to actual continuation
        Task {
            for await element in proxyStream {
                // Check buffer and handle backpressure
                if buffer.count >= bufferSize {
                    // Wait for space in buffer
                    await withCheckedContinuation { continuation in
                        waitingProducers.append(continuation)
                    }
                }
                
                buffer.append(element)
                self.continuation.yield(element)
            }
        }
        
        await build(proxyContinuation)
    }
    
    private func handleYield(result: AsyncStream<Element>.Continuation.YieldResult) async {
        switch result {
        case .enqueued(let remaining):
            // Check if we need to resume waiting producers
            if remaining > 0 && !waitingProducers.isEmpty {
                let producer = waitingProducers.removeFirst()
                producer.resume()
            }
            
        case .dropped:
            // Value was dropped due to buffer being full
            break
            
        case .terminated:
            continuation.finish()
            
        @unknown default:
            break
        }
    }
}

// MARK: - Throttled AsyncStream

/// AsyncStream with throttling capability
public struct ThrottledAsyncStream<Element: Sendable>: AsyncSequence {
    public typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    
    private let stream: AsyncStream<Element>
    
    public init(
        _ elementType: Element.Type = Element.self,
        interval: Duration,
        latest: Bool = true,
        build: @escaping (AsyncStream<Element>.Continuation) async -> Void
    ) {
        self.stream = AsyncStream { continuation in
            Task {
                let throttler = StreamThrottler(
                    interval: interval,
                    latest: latest,
                    continuation: continuation
                )
                await throttler.run(build: build)
            }
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        stream.makeAsyncIterator()
    }
}

// MARK: - Stream Throttler

private actor StreamThrottler<Element: Sendable> {
    private let interval: Duration
    private let latest: Bool
    private let continuation: AsyncStream<Element>.Continuation
    private var lastEmitTime: ContinuousClock.Instant?
    private var pendingValue: Element?
    private var throttleTask: Task<Void, Never>?
    
    init(
        interval: Duration,
        latest: Bool,
        continuation: AsyncStream<Element>.Continuation
    ) {
        self.interval = interval
        self.latest = latest
        self.continuation = continuation
    }
    
    func run(build: @escaping (AsyncStream<Element>.Continuation) async -> Void) async {
        // Create a proxy stream to intercept and throttle yields
        let (proxyStream, proxyContinuation) = AsyncStream<Element>.makeStream()
        
        // Start consuming the proxy stream and throttle forwarding
        Task {
            for await element in proxyStream {
                await self.yield(element)
            }
            continuation.finish()
        }
        
        await build(proxyContinuation)
    }
    
    private func handleYield(result: AsyncStream<Element>.Continuation.YieldResult) async {
        switch result {
        case .enqueued:
            // Handled by the wrapper
            break
            
        case .dropped:
            break
            
        case .terminated:
            throttleTask?.cancel()
            continuation.finish()
            
        @unknown default:
            break
        }
    }
    
    func yield(_ value: Element) async {
        let now = ContinuousClock.now
        
        if let lastEmit = lastEmitTime {
            let elapsed = now - lastEmit
            
            if elapsed < interval {
                // Within throttle window
                if latest {
                    pendingValue = value
                    scheduleEmit()
                }
                // If not latest, drop the value
            } else {
                // Outside throttle window, emit immediately
                continuation.yield(value)
                lastEmitTime = now
            }
        } else {
            // First value, emit immediately
            continuation.yield(value)
            lastEmitTime = now
        }
    }
    
    private func scheduleEmit() {
        guard throttleTask == nil else { return }
        
        throttleTask = Task { [weak self] in
            guard let self = self else { return }
            
            if let lastEmit = await self.lastEmitTime {
                let remaining = await self.interval - (ContinuousClock.now - lastEmit)
                if remaining > .zero {
                    try? await Task.sleep(for: remaining)
                }
            }
            
            if let value = await self.pendingValue {
                await self.continuation.yield(value)
                await self.setPendingValue(nil)
                await self.setLastEmitTime(ContinuousClock.now)
            }
            
            await self.setThrottleTask(nil)
        }
    }
    
    private func setPendingValue(_ value: Element?) {
        pendingValue = value
    }
    
    private func setLastEmitTime(_ time: ContinuousClock.Instant) {
        lastEmitTime = time
    }
    
    private func setThrottleTask(_ task: Task<Void, Never>?) {
        throttleTask = task
    }
}

// MARK: - AsyncSequence Extensions

public extension AsyncSequence {
    /// Throttle the async sequence with a specified interval
    func throttle(
        for interval: Duration,
        clock: some Clock<Duration> = ContinuousClock(),
        latest: Bool = true
    ) -> AsyncThrottleSequence<Self, ContinuousClock> {
        AsyncThrottleSequence(
            base: self,
            interval: interval,
            clock: ContinuousClock(),
            latest: latest
        )
    }
    
    /// Apply backpressure strategy to the sequence
    func withBackpressure(
        _ strategy: BackpressureStrategy
    ) -> AsyncBackpressureSequence<Self> {
        AsyncBackpressureSequence(base: self, strategy: strategy)
    }
}

// MARK: - AsyncThrottleSequence

public struct AsyncThrottleSequence<Base: AsyncSequence, C: Clock>: AsyncSequence where C.Duration == Duration {
    public typealias Element = Base.Element
    
    private let base: Base
    private let interval: Duration
    private let clock: C
    private let latest: Bool
    
    init(base: Base, interval: Duration, clock: C, latest: Bool) {
        self.base = base
        self.interval = interval
        self.clock = clock
        self.latest = latest
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let interval: Duration
        private let clock: C
        private let latest: Bool
        private var lastEmitTime: C.Instant?
        
        init(
            baseIterator: Base.AsyncIterator,
            interval: Duration,
            clock: C,
            latest: Bool
        ) {
            self.baseIterator = baseIterator
            self.interval = interval
            self.clock = clock
            self.latest = latest
        }
        
        public mutating func next() async rethrows -> Element? {
            while let element = try await baseIterator.next() {
                let now = clock.now
                
                if let lastEmit = lastEmitTime {
                    let elapsed = now.duration(to: lastEmit)
                    
                    if elapsed < interval {
                        if !latest {
                            // Skip this element if not keeping latest
                            continue
                        }
                        // Wait for remaining time
                        try? await clock.sleep(for: interval - elapsed)
                    }
                }
                
                lastEmitTime = now
                return element
            }
            
            return nil
        }
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(
            baseIterator: base.makeAsyncIterator(),
            interval: interval,
            clock: clock,
            latest: latest
        )
    }
}

// MARK: - AsyncBackpressureSequence

public struct AsyncBackpressureSequence<Base: AsyncSequence>: AsyncSequence {
    public typealias Element = Base.Element
    
    private let base: Base
    private let strategy: BackpressureStrategy
    
    init(base: Base, strategy: BackpressureStrategy) {
        self.base = base
        self.strategy = strategy
    }
    
    public func makeAsyncIterator() -> AsyncStream<Element>.AsyncIterator {
        let (stream, continuation) = AsyncStream<Element>.makeStream()
        
        Task {
            switch strategy {
            case .dropOldest(let bufferSize):
                var buffer = CircularBuffer<Element>(capacity: bufferSize)
                
                for try await element in base {
                    buffer.append(element)
                    if let oldest = buffer.first {
                        continuation.yield(oldest)
                    }
                }
                
            case .dropNewest(let bufferSize):
                var buffer = CircularBuffer<Element>(capacity: bufferSize)
                
                for try await element in base {
                    if buffer.count < bufferSize {
                        buffer.append(element)
                        continuation.yield(element)
                    }
                    // Drop new elements when buffer is full
                }
                
            case .unbounded:
                for try await element in base {
                    continuation.yield(element)
                }
                
            case .blocking(let bufferSize):
                var buffer = CircularBuffer<Element>(capacity: bufferSize)
                
                for try await element in base {
                    while buffer.count >= bufferSize {
                        // Wait for consumer to process
                        try? await Task.sleep(for: .milliseconds(10))
                    }
                    buffer.append(element)
                    continuation.yield(element)
                }
            }
            
            continuation.finish()
        }
        
        return stream.makeAsyncIterator()
    }
}

// MARK: - Circular Buffer

private struct CircularBuffer<Element> {
    private var storage: [Element?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0
    let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }
    
    mutating func append(_ element: Element) {
        storage[tail] = element
        tail = (tail + 1) % capacity
        
        if count < capacity {
            count += 1
        } else {
            head = (head + 1) % capacity
        }
    }
    
    var first: Element? {
        guard count > 0 else { return nil }
        return storage[head]
    }
    
    mutating func removeFirst() -> Element? {
        guard count > 0 else { return nil }
        
        let element = storage[head]
        storage[head] = nil
        head = (head + 1) % capacity
        count -= 1
        
        return element
    }
}

// MARK: - Usage Examples

public struct AsyncStreamExamples {
    /// Example: Stream with backpressure dropping oldest values
    public static func backpressureExample() async {
        let stream = BackpressureAsyncStream(Int.self, strategy: .dropOldest(bufferSize: 10)) { continuation in
            for i in 0..<100 {
                continuation.yield(i)
                try? await Task.sleep(for: .milliseconds(10))
            }
            continuation.finish()
        }
        
        for await value in stream {
            print("Received: \(value)")
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    
    /// Example: Throttled stream emitting at most once per second
    public static func throttleExample() async {
        let stream = ThrottledAsyncStream(Int.self, interval: .seconds(1)) { continuation in
            for i in 0..<10 {
                continuation.yield(i)
                try? await Task.sleep(for: .milliseconds(100))
            }
            continuation.finish()
        }
        
        for await value in stream {
            print("Throttled: \(value)")
        }
    }
    
    /// Example: Combining backpressure and throttling
    public static func combinedExample() async {
        let stream = BackpressureAsyncStream(Int.self, strategy: .dropNewest(bufferSize: 20)) { continuation in
            for i in 0..<100 {
                continuation.yield(i)
                try? await Task.sleep(for: .milliseconds(10))
            }
            continuation.finish()
        }
        
        for await value in stream.throttle(for: .milliseconds(500)) {
            print("Combined: \(value)")
        }
    }
}