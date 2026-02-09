import Foundation

enum InsightMetric: String {
    case cpu
    case memory
    case disk

    var title: String {
        switch self {
        case .cpu:
            return "CPU"
        case .memory:
            return "Memory"
        case .disk:
            return "Disk"
        }
    }

    var subtitle: String {
        switch self {
        case .cpu:
            return "프로세스 CPU 사용률 Top"
        case .memory:
            return "프로세스 메모리 사용량 Top"
        case .disk:
            return "홈 디렉터리 용량 Top"
        }
    }

    var unitHint: String {
        switch self {
        case .cpu:
            return "%"
        case .memory, .disk:
            return "bytes"
        }
    }
}

struct InsightRow: Identifiable {
    let id: String
    let title: String
    let detail: String
    let valueText: String
    let numericValue: Double
}

@MainActor
final class SystemInsights: ObservableObject {
    @Published private(set) var selectedMetric: InsightMetric?
    @Published private(set) var rows: [InsightRow] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let topN: Int

    init(topN: Int = 7) {
        self.topN = topN
    }

    func show(metric: InsightMetric) {
        selectedMetric = metric
        isLoading = true
        errorMessage = nil
        rows = []
        let topN = self.topN

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.fetch(metric: metric, topN: topN)
            }.value

            if selectedMetric != metric {
                return
            }

            rows = result.rows
            errorMessage = result.error

            isLoading = false
        }
    }

    func close() {
        selectedMetric = nil
        rows = []
        errorMessage = nil
        isLoading = false
    }

    private struct ShellResult {
        let stdout: String
        let stderr: String
        let status: Int32
    }

    private struct FetchResult {
        let rows: [InsightRow]
        let error: String?
    }

    private nonisolated static func fetch(metric: InsightMetric, topN: Int) -> FetchResult {
        switch metric {
        case .cpu:
            return fetchTopCPU(topN: topN)
        case .memory:
            return fetchTopMemory(topN: topN)
        case .disk:
            return fetchTopDisk(topN: topN)
        }
    }

    private nonisolated static func fetchTopCPU(topN: Int) -> FetchResult {
        let result = runCommand(
            "/bin/ps",
            arguments: ["-Ao", "pid=,pcpu=,comm="]
        )

        if result.status != 0 {
            let error = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return FetchResult(rows: [], error: error.isEmpty ? "CPU 정보를 가져오지 못했습니다." : error)
        }

        var rows: [InsightRow] = []

        for rawLine in result.stdout.split(whereSeparator: \ .isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let parts = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count == 3 else { continue }

            guard
                let pid = Int(parts[0]),
                let cpu = Double(parts[1]),
                cpu >= 0
            else {
                continue
            }

            let command = parts[2].trimmingCharacters(in: .whitespaces)
            guard !command.isEmpty else { continue }

            rows.append(
                InsightRow(
                    id: "cpu-\(pid)",
                    title: command,
                    detail: "PID \(pid)",
                    valueText: String(format: "%.1f%%", cpu),
                    numericValue: cpu
                )
            )
        }

        let sorted = rows
            .sorted { $0.numericValue > $1.numericValue }
            .prefix(topN)

        return FetchResult(rows: Array(sorted), error: nil)
    }

    private nonisolated static func fetchTopMemory(topN: Int) -> FetchResult {
        let result = runCommand(
            "/bin/ps",
            arguments: ["-Ao", "pid=,rss=,comm="]
        )

        if result.status != 0 {
            let error = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return FetchResult(rows: [], error: error.isEmpty ? "메모리 정보를 가져오지 못했습니다." : error)
        }

        var rows: [InsightRow] = []

        for rawLine in result.stdout.split(whereSeparator: \ .isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let parts = line.split(maxSplits: 2, whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            guard parts.count == 3 else { continue }

            guard
                let pid = Int(parts[0]),
                let rssKB = Double(parts[1]),
                rssKB >= 0
            else {
                continue
            }

            let bytes = rssKB * 1024
            let command = parts[2].trimmingCharacters(in: .whitespaces)
            guard !command.isEmpty else { continue }

            rows.append(
                InsightRow(
                    id: "mem-\(pid)",
                    title: command,
                    detail: "PID \(pid)",
                    valueText: formatBytes(bytes),
                    numericValue: bytes
                )
            )
        }

        let sorted = rows
            .sorted { $0.numericValue > $1.numericValue }
            .prefix(topN)

        return FetchResult(rows: Array(sorted), error: nil)
    }

    private nonisolated static func fetchTopDisk(topN: Int) -> FetchResult {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let fm = FileManager.default

        let contents: [URL]
        do {
            contents = try fm.contentsOfDirectory(
                at: homeURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return FetchResult(rows: [], error: "디스크 정보를 가져오지 못했습니다: \(error.localizedDescription)")
        }

        var rows: [InsightRow] = []

        for item in contents {
            let result = runCommand(
                "/usr/bin/du",
                arguments: ["-sk", item.path]
            )

            guard result.status == 0 else { continue }
            let firstToken = result.stdout
                .split(whereSeparator: { $0 == "\t" || $0 == " " || $0 == "\n" })
                .first

            guard
                let token = firstToken,
                let sizeKB = Double(token)
            else {
                continue
            }

            let bytes = sizeKB * 1024
            rows.append(
                InsightRow(
                    id: "disk-\(item.path)",
                    title: item.lastPathComponent,
                    detail: item.path,
                    valueText: formatBytes(bytes),
                    numericValue: bytes
                )
            )
        }

        let sorted = rows
            .sorted { $0.numericValue > $1.numericValue }
            .prefix(topN)

        return FetchResult(rows: Array(sorted), error: nil)
    }

    private nonisolated static func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private nonisolated static func runCommand(_ executable: String, arguments: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var env = ProcessInfo.processInfo.environment
        let fallbackPath = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
        env["PATH"] = env["PATH"].map { "\($0):\(fallbackPath)" } ?? fallbackPath
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            return ShellResult(stdout: "", stderr: error.localizedDescription, status: -1)
        }

        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ShellResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            status: process.terminationStatus
        )
    }
}
