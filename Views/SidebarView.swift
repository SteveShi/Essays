import SwiftUI

struct SidebarView: View {
    @Environment(AppState.self) var appState
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            headerSection
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    quickActionsSection
                    
                    calendarSection
                    
                    tagsSection
                    
                    filtersSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            
            Divider()
            
            userSection
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            isSearchFocused = true
        }
    }
    
    private var headerSection: some View {
        @Bindable var appState = appState
        return VStack(spacing: 12) {
            HStack {
                Text(String(localized: "Essays", comment: "Application name"))
                    .font(LiquidGlassTheme.typography.title2)
                    .foregroundColor(LiquidGlassTheme.colors.text)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                
                TextField(String(localized: "Search ideas, tags, keywords...", comment: "Search bar placeholder"), text: $appState.searchText)
                    .textFieldStyle(.plain)
                    .font(LiquidGlassTheme.typography.callout)
                    .focused($isSearchFocused)
                
                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .padding(.horizontal, 16)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: String(localized: "Inbox", comment: "Sidebar section header for main actions"))
            
            VStack(spacing: 4) {
                SidebarItem(
                    icon: "note.text",
                    title: String(localized: "All Memos", comment: "Sidebar item for all memos"),
                    count: appState.memos.count,
                    isSelected: appState.selectedTag == nil && appState.searchText.isEmpty
                ) {
                    appState.searchText = ""
                    appState.selectedTag = nil
                }
                
                SidebarItem(
                    icon: "sun.max",
                    title: String(localized: "Today", comment: "Sidebar item for today's memos"),
                    count: appState.todayMemosCount,
                    isSelected: appState.searchText.lowercased().contains("created:today")
                ) {
                    appState.searchText = "created:today"
                    appState.selectedTag = nil
                }
                
                SidebarItem(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Past 7 Days", comment: "Sidebar item for memos in the last week"),
                    count: appState.recentWeekMemosCount,
                    isSelected: appState.searchText.lowercased().contains("created:7d")
                ) {
                    appState.searchText = "created:7d"
                    appState.selectedTag = nil
                }
                
                SidebarItem(
                    icon: "archivebox",
                    title: String(localized: "Archived", comment: "Sidebar item for archived memos"),
                    count: appState.archivedMemosCount,
                    isSelected: appState.searchText.lowercased().contains("is:archived")
                ) {
                    appState.searchText = "is:archived"
                    appState.selectedTag = nil
                }

                SidebarItem(
                    icon: "photo.on.rectangle.angled",
                    title: String(localized: "Attachments", comment: "Sidebar item for image gallery"),
                    count: appState.memos.reduce(0) { $0 + $1.attachments.filter { $0.isImage }.count },
                    isSelected: appState.isGalleryMode
                ) {
                    appState.searchText = ""
                    appState.selectedTag = nil
                    appState.isGalleryMode = true
                }
            }
        }
    }
    
    private var calendarSection: some View {
        SidebarCalendarView()
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: String(localized: "Tags", comment: "Sidebar section header for tags"))
            
            if appState.tags.isEmpty {
                Text(String(localized: "No tags yet", comment: "Message shown when no tags are available"))
                    .font(LiquidGlassTheme.typography.footnote)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                    .padding(.leading, 4)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(appState.tags.prefix(20)) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: appState.selectedTag == tag.name
                        ) {
                            if appState.selectedTag == tag.name {
                                appState.selectedTag = nil
                            } else {
                                appState.selectedTag = tag.name
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: String(localized: "Visibility", comment: "Sidebar section header for visibility filters"))
            
            VStack(spacing: 4) {
                SidebarItem(
                    icon: "globe",
                    title: String(localized: "Public", comment: "Sidebar item for public memos"),
                    count: appState.publicMemosCount,
                    isSelected: appState.searchText.lowercased().contains("visibility:public")
                ) {
                    appState.searchText = "visibility:public"
                    appState.selectedTag = nil
                }
                
                SidebarItem(
                    icon: MemoVisibility.protected.icon,
                    title: MemoVisibility.protected.displayName,
                    count: appState.memos.filter { $0.visibility == .protected }.count,
                    isSelected: appState.searchText.lowercased().contains("visibility:workspace")
                        || appState.searchText.lowercased().contains("visibility:protected")
                ) {
                    appState.searchText = "visibility:workspace"
                    appState.selectedTag = nil
                }

                SidebarItem(
                    icon: "lock",
                    title: String(localized: "Private", comment: "Sidebar item for private memos"),
                    count: appState.privateMemosCount,
                    isSelected: appState.searchText.lowercased().contains("visibility:private")
                ) {
                    appState.searchText = "visibility:private"
                    appState.selectedTag = nil
                }
            }
        }
    }
    
    private var userSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LiquidGlassTheme.colors.accent.gradient)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(appState.currentUser?.displayNameResolved.prefix(1).uppercased() ?? String(localized: "Me", comment: "Fallback for user avatar if name is missing"))
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    appState.currentUser?.displayNameResolved
                        ?? String(localized: "Guest", comment: "Fallback for user display name"))
                    .font(LiquidGlassTheme.typography.subheadline)
                    .foregroundColor(LiquidGlassTheme.colors.text)
                
                Text(
                    appState.isOnline
                        ? String(localized: "Online", comment: "Network status: Online")
                        : String(localized: "Offline", comment: "Network status: Offline"))
                    .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(appState.isOnline ? .green : .secondary)
            }
            
            Spacer()
            
            Menu {
                Button {
                    appState.clearCredentials()
                } label: {
                    Label(String(localized: "Sign Out", comment: "Menu item for signing out"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(16)
    }
    
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(LiquidGlassTheme.typography.caption)
            .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            .textCase(.uppercase)
            .tracking(1.5)
            .padding(.leading, 4)
    }
}

struct SidebarItem: View {
    let icon: String
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(
                        isSelected
                            ? LiquidGlassTheme.colors.accent : LiquidGlassTheme.colors.secondaryText
                    )
                    .frame(width: 24)
                
                Text(title)
                    .font(LiquidGlassTheme.typography.body)
                    .foregroundStyle(
                        isSelected
                            ? LiquidGlassTheme.colors.text : LiquidGlassTheme.colors.secondaryText)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(LiquidGlassTheme.typography.caption)
                        .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                            ? LiquidGlassTheme.colors.accent.opacity(0.1)
                            : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct TagChip: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag.name)
                    .font(LiquidGlassTheme.typography.caption)
                
                if tag.count > 0 {
                    Text("\(tag.count)")
                        .font(LiquidGlassTheme.typography.caption2)
                        .opacity(0.7)
                }
            }
            .foregroundColor(isSelected ? .white : LiquidGlassTheme.colors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected
                        ? LiquidGlassTheme.colors.accent
                        : isHovered
                            ? LiquidGlassTheme.colors.accent.opacity(0.2)
                            : LiquidGlassTheme.colors.tagBackground
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(LiquidGlassTheme.animation.easeOut) {
                isHovered = hovering
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    struct Cache {
        var sizes: [CGSize] = []
        var maxWidth: CGFloat = -1
        var result: FlowResult?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.maxWidth = -1  // Force recompute
        cache.result = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize
    {
        let width = proposal.width ?? 0
        if let cached = cache.result, cache.maxWidth == width {
            return cached.size
        }
        let result = FlowResult(in: width, sizes: cache.sizes, spacing: spacing)
        cache.maxWidth = width
        cache.result = result
        return result.size
    }
    
    func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
    ) {
        let width = bounds.width
        let result: FlowResult
        if let cached = cache.result, cache.maxWidth == width {
            result = cached
        } else {
            result = FlowResult(in: width, sizes: cache.sizes, spacing: spacing)
            cache.maxWidth = width
            cache.result = result
        }

        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                subview.place(
                    at: CGPoint(
                        x: bounds.minX + result.positions[index].x,
                        y: bounds.minY + result.positions[index].y), proposal: .unspecified)
            }
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, sizes: [CGSize], spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for size in sizes {
                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

struct SidebarCalendarView: View {
    @Environment(AppState.self) var appState
    @State private var currentMonth: Date = Date()
    @State private var days: [Date] = []
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday
        return cal
    }()
    
    // 缓存日期组件以提高查找性能
    private var memoDateComponents: Set<DateComponents> {
        appState.memoDateComponents
    }

    private func computeDays() {
        // 只有当月份真正改变时才重新计算
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1) else {
            self.days = []
            return
        }
        var dates: [Date] = []
        var date = monthFirstWeek.start
        while date < monthLastWeek.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        self.days = dates
    }
    
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerView

            calendarGrid
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LiquidGlassTheme.colors.cardBackground.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(LiquidGlassTheme.colors.border.opacity(0.5), lineWidth: 0.5)
                        )
                )
        }
        .onAppear {
            computeDays()
        }
        .onChange(of: currentMonth) { _, _ in
            computeDays()
        }
    }

    private var headerView: some View {
        HStack {
            Text(Self.monthFormatter.string(from: currentMonth))
                .font(LiquidGlassTheme.typography.caption)
                .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                .textCase(.uppercase)
                .tracking(1.5)
                .padding(.leading, 4)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 10, weight: .bold))
                }
                Button {
                    currentMonth = Date()
                } label: {
                    Image(systemName: "circle").font(.system(size: 8, weight: .bold))
                }
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            .buttonStyle(.plain)
        }
    }
    
    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(
                [
                    String(localized: "Sun", comment: "Sunday short form"),
                    String(localized: "Mon", comment: "Monday short form"),
                    String(localized: "Tue", comment: "Tuesday short form"),
                    String(localized: "Wed", comment: "Wednesday short form"),
                    String(localized: "Thu", comment: "Thursday short form"),
                    String(localized: "Fri", comment: "Friday short form"),
                    String(localized: "Sat", comment: "Saturday short form"),
                ], id: \.self
            ) { day in
                Text(day)
                    .font(LiquidGlassTheme.typography.caption2)
                    .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
            
            ForEach(days, id: \.timeIntervalSince1970) { date in
                DayButton(date: date, currentMonth: currentMonth, calendar: calendar)
            }
        }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            withAnimation(.easeInOut) {
                currentMonth = newMonth
            }
        }
    }
}

/// 提取子视图以减少全量重绘产生的压力
struct DayButton: View {
    let date: Date
    let currentMonth: Date
    let calendar: Calendar
    @Environment(AppState.self) var appState

    var body: some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let hasMemo = appState.memoDateComponents.contains(components)
        let dateString = DayButton.sharedDateFormatter.string(from: date)
        let isSelected = appState.searchText == "created:\(dateString)"
        let isToday = calendar.isDateInToday(date)

        return Button {
            if isSelected {
                appState.searchText = ""
            } else {
                appState.searchText = "created:\(dateString)"
                appState.selectedTag = nil
            }
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(
                    .system(
                        size: 12, weight: isSelected || isToday ? .semibold : .regular,
                        design: .rounded)
                )
                .frame(width: 24, height: 24)
                .foregroundStyle(
                    isCurrentMonth
                        ? (isSelected
                            ? .white
                            : (isToday
                                ? LiquidGlassTheme.colors.accent
                                : LiquidGlassTheme.colors.text))
                        : LiquidGlassTheme.colors.tertiaryText.opacity(0.3)
                )
                .background(
                    ZStack {
                        if isSelected {
                            Circle().fill(LiquidGlassTheme.colors.accent)
                        } else if hasMemo {
                            Circle().fill(LiquidGlassTheme.colors.accent.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .disabled(!hasMemo && !isToday && !isSelected)
    }
    
    private static let sharedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
