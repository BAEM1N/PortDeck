import SwiftUI

private enum PortBandFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case system = "1-1023"
    case registered = "1024-49151"
    case dynamic = "49152-65535"

    var id: String { rawValue }

    var title: String { rawValue }

    var band: PortBand? {
        switch self {
        case .all:
            return nil
        case .system:
            return .system
        case .registered:
            return .registered
        case .dynamic:
            return .dynamic
        }
    }
}

private enum SearchToken {
    case port(Int)
    case range(ClosedRange<Int>)
    case text(String)

    static func parse(from rawQuery: String) -> [SearchToken] {
        rawQuery
            .split(separator: ",", omittingEmptySubsequences: true)
            .compactMap { rawToken in
                let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else { return nil }

                if let range = parseRange(from: token) {
                    return .range(range)
                }

                if
                    let port = Int(token),
                    (1...65_535).contains(port)
                {
                    return .port(port)
                }

                return .text(token.lowercased())
            }
    }

    private static func parseRange(from token: String) -> ClosedRange<Int>? {
        let parts = token.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return nil
        }

        let left = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let right = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let start = Int(left),
            let end = Int(right),
            (1...65_535).contains(start),
            (1...65_535).contains(end)
        else {
            return nil
        }

        return min(start, end)...max(start, end)
    }

    func matches(entry: PortProcess) -> Bool {
        switch self {
        case .port(let value):
            return entry.port == value
        case .range(let value):
            return value.contains(entry.port)
        case .text(let keyword):
            if String(entry.port).contains(keyword) {
                return true
            }

            let fields = [entry.processName, entry.ownerName, entry.commandLine, entry.cwd]
            return fields.contains { $0.lowercased().contains(keyword) }
        }
    }
}

private struct AdaptiveTheme {
    let backgroundGradient: [Color]
    let glowPrimary: Color
    let glowSecondary: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let cardFill: Color
    let cardBorder: Color
    let rowFill: Color
    let rowBorder: Color
    let fieldFill: Color
    let fieldBorder: Color
    let statusFill: Color
    let accent: Color
    let danger: Color
    let cpuTone: Color
    let memoryTone: Color
    let diskTone: Color

    static func make(for colorScheme: ColorScheme) -> AdaptiveTheme {
        if colorScheme == .dark {
            return AdaptiveTheme(
                backgroundGradient: [
                    Color(red: 0.06, green: 0.09, blue: 0.14),
                    Color(red: 0.09, green: 0.16, blue: 0.22),
                    Color(red: 0.14, green: 0.15, blue: 0.10)
                ],
                glowPrimary: Color(red: 0.21, green: 0.67, blue: 0.95).opacity(0.24),
                glowSecondary: Color(red: 0.95, green: 0.63, blue: 0.18).opacity(0.20),
                textPrimary: .white,
                textSecondary: Color.white.opacity(0.84),
                textTertiary: Color.white.opacity(0.64),
                cardFill: Color.white.opacity(0.09),
                cardBorder: Color.white.opacity(0.14),
                rowFill: Color.black.opacity(0.20),
                rowBorder: Color.white.opacity(0.09),
                fieldFill: Color.white.opacity(0.15),
                fieldBorder: Color.white.opacity(0.16),
                statusFill: Color.black.opacity(0.23),
                accent: Color(red: 0.11, green: 0.62, blue: 0.88),
                danger: Color(red: 0.93, green: 0.40, blue: 0.30),
                cpuTone: Color(red: 0.12, green: 0.70, blue: 0.95),
                memoryTone: Color(red: 0.21, green: 0.79, blue: 0.50),
                diskTone: Color(red: 0.97, green: 0.67, blue: 0.18)
            )
        }

        return AdaptiveTheme(
            backgroundGradient: [
                Color(red: 0.92, green: 0.96, blue: 0.99),
                Color(red: 0.89, green: 0.94, blue: 1.00),
                Color(red: 0.96, green: 0.94, blue: 0.88)
            ],
            glowPrimary: Color(red: 0.25, green: 0.58, blue: 0.92).opacity(0.20),
            glowSecondary: Color(red: 0.94, green: 0.61, blue: 0.20).opacity(0.14),
            textPrimary: Color(red: 0.10, green: 0.16, blue: 0.20),
            textSecondary: Color(red: 0.19, green: 0.25, blue: 0.30),
            textTertiary: Color(red: 0.30, green: 0.37, blue: 0.42),
            cardFill: Color.white.opacity(0.66),
            cardBorder: Color.black.opacity(0.08),
            rowFill: Color.white.opacity(0.72),
            rowBorder: Color.black.opacity(0.08),
            fieldFill: Color.white.opacity(0.80),
            fieldBorder: Color.black.opacity(0.12),
            statusFill: Color.white.opacity(0.78),
            accent: Color(red: 0.14, green: 0.50, blue: 0.87),
            danger: Color(red: 0.86, green: 0.36, blue: 0.29),
            cpuTone: Color(red: 0.13, green: 0.57, blue: 0.92),
            memoryTone: Color(red: 0.14, green: 0.67, blue: 0.40),
            diskTone: Color(red: 0.90, green: 0.58, blue: 0.16)
        )
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var portManager = PortManager()
    @StateObject private var systemMonitor = SystemMonitor()
    @StateObject private var systemInsights = SystemInsights(topN: 7)
    @State private var searchQuery = ""
    @State private var bandFilter: PortBandFilter = .all
    @State private var pinnedInsightMetric: InsightMetric?
    @State private var hoveredMetrics: Set<InsightMetric> = []
    @State private var hoverCloseTask: Task<Void, Never>?

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    private var theme: AdaptiveTheme {
        AdaptiveTheme.make(for: colorScheme)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(theme.glowPrimary)
                    .frame(width: 230, height: 230)
                    .blur(radius: 42)
                    .offset(x: -58, y: -92)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(theme.glowSecondary)
                    .frame(width: 200, height: 200)
                    .blur(radius: 44)
                    .offset(x: 70, y: 84)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    SystemMetricsCard(
                        snapshot: systemMonitor.snapshot,
                        byteFormatter: byteFormatter,
                        theme: theme,
                        topN: systemInsights.topN,
                        onTapMetric: { metric in
                            pinInsight(metric)
                        },
                        onHoverMetric: { metric, isHovering in
                            handleMetricHover(metric: metric, isHovering: isHovering)
                        }
                    )

                    if let selectedMetric = systemInsights.selectedMetric {
                        insightCard(for: selectedMetric)
                    }

                    filterCard

                    if let statusMessage = portManager.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(theme.statusFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    portListCard

                    Text("예: FastAPI/uvicorn이 8000번 점유 중이면 PID 종료 또는 포트 종료를 실행하세요.")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(theme.textTertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 640, height: 760)
        .onAppear {
            portManager.refresh()
            systemMonitor.start()
        }
        .onDisappear {
            hoverCloseTask?.cancel()
            systemMonitor.stop()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppBrand.displayName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)

                Text(AppBrand.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            if portManager.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                portManager.refresh()
                systemMonitor.refresh()
            } label: {
                Label("새로고침", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
        }
    }

    private var filterCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)

                    TextField("검색 예: 8000, 3000:3999, uvicorn", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textPrimary)

                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.fieldFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.fieldBorder, lineWidth: 1)
                )

                Button {
                    terminateBySearchPorts()
                } label: {
                    Label("포트 종료", systemImage: "stop.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.danger)
            }

            Text("검색/종료 문법: 숫자(단일), `시작:끝`(대역), `,`(여러 포트). 텍스트 토큰은 검색에만 사용됩니다.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)

            Picker("구간", selection: $bandFilter) {
                ForEach(PortBandFilter.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private var filteredEntries: [PortProcess] {
        var entries = portManager.entries

        if bandFilter != .system {
            entries = entries.filter { $0.portBand != .system }
        }

        if let selectedBand = bandFilter.band {
            entries = entries.filter { $0.portBand == selectedBand }
        }

        let tokens = SearchToken.parse(from: searchQuery)
        if tokens.isEmpty {
            return entries
        }

        return entries.filter { entry in
            tokens.contains { $0.matches(entry: entry) }
        }
    }

    private var portSections: [PortSection] {
        let grouped = Dictionary(grouping: filteredEntries, by: \.portBand)
        let order = bandFilter.band.map { [$0] } ?? PortBand.displayOrder

        return order.compactMap { band in
            guard let entries = grouped[band], !entries.isEmpty else {
                return nil
            }

            let sorted = entries.sorted {
                if $0.port == $1.port {
                    return $0.pid < $1.pid
                }
                return $0.port < $1.port
            }

            return PortSection(band: band, entries: sorted)
        }
    }

    private var portListCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("LISTEN 포트")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Text("\(filteredEntries.count)/\(portManager.entries.count)개")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }

            if portManager.entries.isEmpty {
                Text(portManager.isLoading ? "포트를 조회 중입니다..." : "현재 LISTEN 중인 TCP 포트가 없습니다.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 290, alignment: .center)
            } else if portSections.isEmpty {
                Text("현재 필터 기준으로 표시할 항목이 없습니다.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 290, alignment: .center)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(portSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(section.band.stageTitle)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textSecondary)

                                Spacer()

                                Text("\(section.entries.count)개")
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                            }

                            ForEach(section.entries) { entry in
                                PortRow(entry: entry, theme: theme) {
                                    portManager.terminate(pid: entry.pid)
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.rowFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(theme.rowBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }

    private enum SearchPortResolution {
        case valid([Int])
        case noNumericToken
        case noMatchingPort
    }

    private func resolvePortsFromSearch() -> SearchPortResolution {
        let tokens = SearchToken.parse(from: searchQuery)
        guard !tokens.isEmpty else {
            return .noNumericToken
        }

        var directPorts: [Int] = []
        var ranges: [ClosedRange<Int>] = []

        for token in tokens {
            switch token {
            case .port(let port):
                directPorts.append(port)
            case .range(let range):
                ranges.append(range)
            case .text:
                continue
            }
        }

        if directPorts.isEmpty && ranges.isEmpty {
            return .noNumericToken
        }

        var resolved = Set(directPorts)
        if !ranges.isEmpty {
            let activePorts = Set(portManager.entries.map(\.port))
            for range in ranges {
                for port in activePorts where range.contains(port) {
                    resolved.insert(port)
                }
            }
        }

        let sorted = resolved.sorted()
        if sorted.isEmpty {
            return .noMatchingPort
        }

        return .valid(sorted)
    }

    private func terminateBySearchPorts() {
        switch resolvePortsFromSearch() {
        case .valid(let ports):
            portManager.terminatePorts(ports)
        case .noNumericToken:
            portManager.statusMessage = "종료할 포트를 숫자/범위로 입력하세요. 예: 8000, 3000:3999, 8000,8080"
        case .noMatchingPort:
            portManager.statusMessage = "입력 범위에서 현재 LISTEN 중인 포트를 찾지 못했습니다."
        }
    }

    private func showInsightIfNeeded(_ metric: InsightMetric) {
        if systemInsights.selectedMetric != metric || systemInsights.rows.isEmpty {
            systemInsights.show(metric: metric)
        }
    }

    private func pinInsight(_ metric: InsightMetric) {
        pinnedInsightMetric = metric
        showInsightIfNeeded(metric)
    }

    private func closeInsightPanel() {
        pinnedInsightMetric = nil
        if let firstHovered = hoveredMetrics.first {
            showInsightIfNeeded(firstHovered)
        } else {
            systemInsights.close()
        }
    }

    private func handleMetricHover(metric: InsightMetric, isHovering: Bool) {
        hoverCloseTask?.cancel()

        if isHovering {
            hoveredMetrics.insert(metric)
            if pinnedInsightMetric == nil {
                showInsightIfNeeded(metric)
            }
            return
        }

        hoveredMetrics.remove(metric)
        guard pinnedInsightMetric == nil else {
            return
        }

        if let firstHovered = hoveredMetrics.first {
            showInsightIfNeeded(firstHovered)
            return
        }

        hoverCloseTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if pinnedInsightMetric == nil && hoveredMetrics.isEmpty {
                    systemInsights.close()
                }
            }
        }
    }

    private func insightCard(for metric: InsightMetric) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(metric.title) TOP \(systemInsights.topN)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)

                    Text(metric.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                Button {
                    systemInsights.show(metric: metric)
                } label: {
                    Label("다시", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    closeInsightPanel()
                } label: {
                    Label("닫기", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }

            if systemInsights.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Top 목록을 계산 중입니다...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.vertical, 8)
            } else if let error = systemInsights.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.danger)
            } else if systemInsights.rows.isEmpty {
                Text("표시할 데이터가 없습니다.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(systemInsights.rows.enumerated()), id: \.element.id) { index, row in
                        HStack(alignment: .top, spacing: 8) {
                            Text("#\(index + 1)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.textTertiary)
                                .frame(width: 24, alignment: .leading)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.title)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)

                                Text(row.detail)
                                    .font(.system(size: 10, weight: .regular, design: .rounded))
                                    .foregroundStyle(theme.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer(minLength: 0)

                            Text(row.valueText)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(theme.textSecondary)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.rowFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(theme.rowBorder, lineWidth: 1)
                                )
                        )
                    }
                }
            }

            if metric == .disk {
                Text("Disk Top은 홈 디렉터리 기준 항목 용량입니다.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct SystemMetricsCard: View {
    let snapshot: SystemSnapshot
    let byteFormatter: ByteCountFormatter
    let theme: AdaptiveTheme
    let topN: Int
    let onTapMetric: (InsightMetric) -> Void
    let onHoverMetric: (InsightMetric, Bool) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("시스템 리소스")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                Text("마우스 오버/클릭 시 TOP \(topN)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }

            HStack(spacing: 10) {
                MetricTile(
                    title: "CPU",
                    value: String(format: "%.1f%%", snapshot.cpuPercent),
                    caption: "사용률",
                    icon: "cpu.fill",
                    progress: min(snapshot.cpuPercent / 100, 1),
                    tone: theme.cpuTone,
                    theme: theme,
                    onTap: {
                        onTapMetric(.cpu)
                    },
                    onHoverChanged: { hovering in
                        onHoverMetric(.cpu, hovering)
                    }
                )

                MetricTile(
                    title: "Memory",
                    value: String(format: "%.1f%%", snapshot.memoryPercent),
                    caption: "\(byteFormatter.string(fromByteCount: Int64(snapshot.memoryUsedBytes))) / \(byteFormatter.string(fromByteCount: Int64(snapshot.memoryTotalBytes)))",
                    icon: "memorychip.fill",
                    progress: min(snapshot.memoryPercent / 100, 1),
                    tone: theme.memoryTone,
                    theme: theme,
                    onTap: {
                        onTapMetric(.memory)
                    },
                    onHoverChanged: { hovering in
                        onHoverMetric(.memory, hovering)
                    }
                )
            }

            MetricTile(
                title: "Disk",
                value: String(format: "%.1f%%", snapshot.diskPercent),
                caption: "\(byteFormatter.string(fromByteCount: Int64(snapshot.diskUsedBytes))) / \(byteFormatter.string(fromByteCount: Int64(snapshot.diskTotalBytes)))",
                icon: "internaldrive.fill",
                progress: min(snapshot.diskPercent / 100, 1),
                tone: theme.diskTone,
                theme: theme,
                onTap: {
                    onTapMetric(.disk)
                },
                onHoverChanged: { hovering in
                    onHoverMetric(.disk, hovering)
                }
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let caption: String
    let icon: String
    let progress: Double
    let tone: Color
    let theme: AdaptiveTheme
    let onTap: (() -> Void)?
    let onHoverChanged: ((Bool) -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    content
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onHover { hovering in
                    onHoverChanged?(hovering)
                }
            } else {
                content
                    .onHover { hovering in
                        onHoverChanged?(hovering)
                    }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone)

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textSecondary)

                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
            }

            ProgressView(value: progress)
                .tint(tone)

            Text(caption)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.rowBorder, lineWidth: 1)
                )
        )
    }
}

private struct PortRow: View {
    let entry: PortProcess
    let theme: AdaptiveTheme
    let terminate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(":\(entry.port)  \(entry.processName) (PID \(entry.pid))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textPrimary)

                    Text(entry.ownerName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.fieldFill, in: Capsule())
                }

                Text(entry.commandLine)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                Text("cwd: \(entry.cwd)")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            Button("PID 종료", role: .destructive) {
                terminate()
            }
            .buttonStyle(.bordered)
            .tint(theme.danger)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct PortSection: Identifiable {
    let band: PortBand
    let entries: [PortProcess]

    var id: PortBand {
        band
    }
}
