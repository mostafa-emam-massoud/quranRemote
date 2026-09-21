import Foundation

/// Fetches and caches mushaf pages.
///
/// Every page that has ever been shown is written to disk as JSON, so the
/// reader keeps working in a masjid with no signal. "Download the whole
/// mushaf" is the same path, run over all 604 pages.
public actor PageStore {

    public struct DownloadProgress: Equatable, Sendable {
        public var completed: Int
        public var total: Int
        public var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
        public var isFinished: Bool { completed >= total }
    }

    private let provider: PageTextProviding
    private let directory: URL
    private let fileManager: FileManager
    private let memoryLimit: Int

    private var memory: [Int: PageText] = [:]
    private var recentlyUsed: [Int] = []
    private var inFlight: [Int: Task<PageText, Error>] = [:]

    public init(
        provider: PageTextProviding = FallbackPageTextProvider.standard(),
        directory: URL? = nil,
        fileManager: FileManager = .default,
        memoryLimit: Int = 60
    ) {
        self.provider = provider
        self.fileManager = fileManager
        self.memoryLimit = max(memoryLimit, 3)
        if let directory {
            self.directory = directory
        } else {
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.directory = caches.appendingPathComponent("QuranRemote/Pages", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    // MARK: - Reading

    /// A page already in memory or on disk. Never touches the network.
    public func cachedPage(_ page: Int) -> PageText? {
        guard Mushaf.isValid(page: page) else { return nil }
        if let text = memory[page] {
            touch(page)
            return text
        }
        guard let data = try? Data(contentsOf: fileURL(for: page)),
              let text = try? JSONDecoder().decode(PageText.self, from: data)
        else { return nil }
        store(text)
        return text
    }

    /// A page, from cache if possible and from the network otherwise.
    public func page(_ page: Int) async throws -> PageText {
        guard Mushaf.isValid(page: page) else { throw QuranTextError.invalidPage(page) }
        if let cached = cachedPage(page) { return cached }
        if let existing = inFlight[page] { return try await existing.value }

        let task = Task<PageText, Error> { [provider] in
            try await provider.fetchPage(page)
        }
        inFlight[page] = task
        defer { inFlight[page] = nil }

        let text = try await task.value
        store(text)
        persist(text)
        return text
    }

    /// Warms pages in the background; failures are ignored on purpose, the
    /// reader will simply fetch again when the page is actually reached.
    public func prefetch(pages: [Int]) {
        for page in pages where Mushaf.isValid(page: page) && cachedPage(page) == nil && inFlight[page] == nil {
            Task { [weak self] in
                _ = try? await self?.page(page)
            }
        }
    }

    // MARK: - Offline download

    public func downloadedPages() -> Set<Int> {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return [] }
        var pages = Set<Int>()
        for name in names where name.hasPrefix("page-") && name.hasSuffix(".json") {
            let digits = name.dropFirst("page-".count).dropLast(".json".count)
            if let page = Int(digits) { pages.insert(page) }
        }
        return pages
    }

    public func downloadedPageCount() -> Int {
        downloadedPages().count
    }

    /// Downloads every page that is not cached yet, a few at a time.
    /// Cancel by cancelling the surrounding `Task`.
    public func downloadWholeMushaf(
        concurrency: Int = 4,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws {
        let total = Mushaf.pageCount
        let alreadyThere = downloadedPages()
        var completed = alreadyThere.count
        progress(DownloadProgress(completed: completed, total: total))

        let missing = Mushaf.pageRange.filter { !alreadyThere.contains($0) }
        guard !missing.isEmpty else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            var iterator = missing.makeIterator()
            for _ in 0..<max(1, concurrency) {
                guard let next = iterator.next() else { break }
                group.addTask { [weak self] in
                    _ = try? await self?.page(next)
                }
            }
            while try await group.next() != nil {
                completed += 1
                progress(DownloadProgress(completed: completed, total: total))
                try Task.checkCancellation()
                if let next = iterator.next() {
                    group.addTask { [weak self] in
                        _ = try? await self?.page(next)
                    }
                }
            }
        }
    }

    public func clearCache() throws {
        memory.removeAll()
        recentlyUsed.removeAll()
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Plumbing

    private func fileURL(for page: Int) -> URL {
        directory.appendingPathComponent(String(format: "page-%04d.json", page))
    }

    private func persist(_ text: PageText) {
        guard let data = try? JSONEncoder().encode(text) else { return }
        try? data.write(to: fileURL(for: text.pageNumber), options: .atomic)
    }

    private func store(_ text: PageText) {
        memory[text.pageNumber] = text
        touch(text.pageNumber)
        while recentlyUsed.count > memoryLimit, let oldest = recentlyUsed.first {
            recentlyUsed.removeFirst()
            memory[oldest] = nil
        }
    }

    private func touch(_ page: Int) {
        recentlyUsed.removeAll { $0 == page }
        recentlyUsed.append(page)
    }
}
