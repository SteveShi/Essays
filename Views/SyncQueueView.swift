import SwiftUI
import SwiftData

struct SyncQueueView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \OutboxTask.createdAt, order: .reverse) private var tasks: [OutboxTask]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if tasks.isEmpty {
                emptyStateView
            } else {
                taskList
            }
        }
        .background(LiquidGlassTheme.colors.background)
        .navigationTitle(String(localized: "Sync Queue", comment: "Navigation title for sync queue"))
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Sync Queue", comment: "Sync queue title"))
                    .font(LiquidGlassTheme.typography.title2)
                
                let pendingCount = tasks.filter { $0.state == .pending || $0.state == .retry || $0.state == .running }.count
                Text(String(localized: "\(pendingCount) tasks pending", comment: "Pending tasks count"))
                    .font(LiquidGlassTheme.typography.subheadline)
                    .foregroundStyle(LiquidGlassTheme.colors.secondaryText)
            }
            
            Spacer()
            
            Button {
                SyncEngine.shared.triggerSync()
            } label: {
                Label(String(localized: "Sync Now", comment: "Trigger sync button"), systemImage: "arrow.clockwise.icloud")
            }
            .buttonStyle(.borderedProminent)
            .disabled(SyncEngine.shared.isSyncing)
        }
        .padding(24)
        .background(.ultraThinMaterial)
    }
    
    private var taskList: some View {
        List {
            ForEach(tasks) { task in
                taskRow(for: task)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
    
    private func taskRow(for task: OutboxTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(task.type.displayName, systemImage: task.type.icon)
                    .font(LiquidGlassTheme.typography.headline)
                
                Spacer()
                
                statusBadge(for: task)
            }
            
            if let memoId = task.memoId {
                Text("Memo: \(memoId)")
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
            }
            
            if let error = task.lastError {
                Text(error)
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
                Text(task.createdAt.formatted(.relative(presentation: .numeric)))
                    .font(LiquidGlassTheme.typography.caption2)
                    .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                
                Spacer()
                
                if task.attempts > 0 {
                    Text(String(localized: "Attempts: \(task.attempts)", comment: "Retry attempts count"))
                        .font(LiquidGlassTheme.typography.caption2)
                        .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LiquidGlassTheme.colors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
    
    private func statusBadge(for task: OutboxTask) -> some View {
        let (text, color, icon) = switch task.state {
        case .pending: (String(localized: "Pending"), Color.gray, "clock")
        case .running: (String(localized: "Syncing"), Color.blue, "arrow.triangle.2.circlepath")
        case .retry: (String(localized: "Retrying"), Color.orange, "arrow.clockwise")
        case .error: (String(localized: "Failed"), Color.red, "exclamationmark.circle")
        }
        
        return Label(text, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(String(localized: "Queue Clear", comment: "Empty queue title"), systemImage: "checkmark.icloud")
        } description: {
            Text(String(localized: "All local changes have been synchronized with the server.", comment: "Empty queue description"))
        }
    }
}

extension OutboxTaskType {
    var displayName: String {
        switch self {
        case .createMemo: return String(localized: "Create Memo")
        case .updateMemo: return String(localized: "Update Memo")
        case .deleteMemo: return String(localized: "Delete Memo")
        case .archiveMemo: return String(localized: "Archive Memo")
        case .unarchiveMemo: return String(localized: "Unarchive Memo")
        case .togglePinMemo: return String(localized: "Toggle Pin")
        case .unknown: return String(localized: "Unknown Task")
        }
    }
    
    var icon: String {
        switch self {
        case .createMemo: return "plus.square"
        case .updateMemo: return "pencil.and.outline"
        case .deleteMemo: return "trash"
        case .archiveMemo: return "archivebox"
        case .unarchiveMemo: return "arrow.up.bin"
        case .togglePinMemo: return "pin"
        case .unknown: return "questionmark.square"
        }
    }
}
