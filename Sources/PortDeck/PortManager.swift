import Foundation

enum PortBand: CaseIterable, Hashable {
    case system
    case registered
    case dynamic

    static let displayOrder: [PortBand] = [.system, .registered, .dynamic]

    static func from(port: Int) -> PortBand {
        switch port {
        case 1...1_023:
            return .system
        case 1_024...49_151:
            return .registered
        default:
            return .dynamic
        }
    }

    var stageTitle: String {
        switch self {
        case .system:
            return "시스템 포트 (1-1023)"
        case .registered:
            return "일반 포트 (1024-49151)"
        case .dynamic:
            return "동적 포트 (49152-65535)"
        }
    }
}

struct PortProcess: Identifiable, Hashable {
    let pid: Int
    let processName: String
    let port: Int
    let commandLine: String
    let cwd: String
    let ownerName: String

    var id: String {
        "\(pid)-\(port)"
    }

    var portBand: PortBand {
        PortBand.from(port: port)
    }
}

@MainActor
final class PortManager: ObservableObject {
    @Published private(set) var entries: [PortProcess] = []
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?

    func refresh() {
        isLoading = true
        statusMessage = nil

        Task {
            let fetched = await Task.detached(priority: .userInitiated) {
                Self.fetchPortProcesses()
            }.value

            entries = fetched
            isLoading = false
        }
    }

    func terminate(pid: Int) {
        statusMessage = nil

        Task {
            let message = await Task.detached(priority: .userInitiated) {
                Self.terminateProcess(pid: pid)
            }.value

            statusMessage = message
            refresh()
        }
    }

    func terminatePort(_ port: Int) {
        statusMessage = nil

        Task {
            let message = await Task.detached(priority: .userInitiated) {
                Self.terminateByPort(port: port)
            }.value

            statusMessage = message
            refresh()
        }
    }

    private struct PartialPort {
        let pid: Int
        let processName: String
        let port: Int
        let ownerName: String
    }

    private struct ShellResult {
        let stdout: String
        let stderr: String
        let status: Int32
    }

    private nonisolated static func fetchPortProcesses() -> [PortProcess] {
        let listing = runCommand(
            "/usr/sbin/lsof",
            arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-FpcLun"]
        )

        if listing.status != 0 && listing.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }

        let partials = parseListeningPorts(from: listing.stdout)
        if partials.isEmpty {
            return []
        }

        var commandCache: [Int: String] = [:]
        var cwdCache: [Int: String] = [:]
        var mapped: [PortProcess] = []

        for partial in partials {
            if commandCache[partial.pid] == nil {
                commandCache[partial.pid] = fetchCommandLine(pid: partial.pid) ?? partial.processName
            }

            if cwdCache[partial.pid] == nil {
                cwdCache[partial.pid] = fetchCurrentDirectory(pid: partial.pid) ?? "-"
            }

            mapped.append(
                PortProcess(
                    pid: partial.pid,
                    processName: partial.processName,
                    port: partial.port,
                    commandLine: commandCache[partial.pid] ?? partial.processName,
                    cwd: cwdCache[partial.pid] ?? "-",
                    ownerName: partial.ownerName
                )
            )
        }

        return mapped.sorted {
            if $0.port == $1.port {
                return $0.pid < $1.pid
            }
            return $0.port < $1.port
        }
    }

    private nonisolated static func parseListeningPorts(from output: String) -> [PartialPort] {
        var parsed: [PartialPort] = []
        var currentPID: Int?
        var currentProcessName = ""
        var currentOwner = ""
        var currentUID = ""
        var seen = Set<String>()

        for line in output.split(whereSeparator: \ .isNewline) {
            guard let prefix = line.first else {
                continue
            }

            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPID = Int(value)
                currentProcessName = ""
                currentOwner = ""
                currentUID = ""
            case "c":
                currentProcessName = value
            case "L":
                currentOwner = value
            case "u":
                currentUID = value
            case "n":
                guard
                    let pid = currentPID,
                    let port = parsePort(from: value)
                else {
                    continue
                }

                let dedupeKey = "\(pid)-\(port)"
                if seen.insert(dedupeKey).inserted {
                    parsed.append(
                        PartialPort(
                            pid: pid,
                            processName: currentProcessName.isEmpty ? "unknown" : currentProcessName,
                            port: port,
                            ownerName: currentOwner.isEmpty ? (currentUID.isEmpty ? "unknown" : currentUID) : currentOwner
                        )
                    )
                }
            default:
                continue
            }
        }

        return parsed
    }

    private nonisolated static func parsePort(from endpoint: String) -> Int? {
        guard let separator = endpoint.lastIndex(of: ":") else {
            return nil
        }

        let portPart = endpoint[endpoint.index(after: separator)...]
        return Int(portPart)
    }

    private nonisolated static func fetchCommandLine(pid: Int) -> String? {
        let result = runCommand(
            "/bin/ps",
            arguments: ["-p", String(pid), "-o", "command="]
        )

        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private nonisolated static func fetchCurrentDirectory(pid: Int) -> String? {
        let result = runCommand(
            "/usr/sbin/lsof",
            arguments: ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]
        )

        for line in result.stdout.split(whereSeparator: \ .isNewline) {
            guard line.first == "n" else {
                continue
            }
            return String(line.dropFirst())
        }

        return nil
    }

    private nonisolated static func terminateByPort(port: Int) -> String {
        let result = runCommand(
            "/usr/sbin/lsof",
            arguments: ["-tiTCP:\(port)", "-sTCP:LISTEN"]
        )

        let pidLines = result.stdout
            .split(whereSeparator: \ .isNewline)
            .compactMap { Int($0) }

        if pidLines.isEmpty {
            return "포트 \(port)에서 종료할 프로세스를 찾지 못했습니다."
        }

        let uniquePIDs = Array(Set(pidLines)).sorted()
        var terminated = 0

        for pid in uniquePIDs {
            _ = terminateProcess(pid: pid)
            if !isProcessAlive(pid: pid) {
                terminated += 1
            }
        }

        return "포트 \(port)에서 \(terminated)/\(uniquePIDs.count)개 프로세스를 종료했습니다."
    }

    private nonisolated static func terminateProcess(pid: Int) -> String {
        let termResult = runCommand(
            "/bin/kill",
            arguments: ["-TERM", String(pid)]
        )

        if termResult.status != 0 {
            let error = termResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = error.isEmpty ? "" : " (\(error))"
            return "PID \(pid) 종료 실패\(suffix)"
        }

        Thread.sleep(forTimeInterval: 0.35)

        if isProcessAlive(pid: pid) {
            let killResult = runCommand(
                "/bin/kill",
                arguments: ["-KILL", String(pid)]
            )

            if killResult.status != 0 {
                let error = killResult.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = error.isEmpty ? "" : " (\(error))"
                return "PID \(pid) 강제 종료 실패\(suffix)"
            }

            return "PID \(pid) 강제 종료 완료"
        }

        return "PID \(pid) 정상 종료 완료"
    }

    private nonisolated static func isProcessAlive(pid: Int) -> Bool {
        let result = runCommand(
            "/bin/ps",
            arguments: ["-p", String(pid), "-o", "pid="]
        )

        return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ShellResult(stdout: stdout, stderr: stderr, status: process.terminationStatus)
    }
}
