import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
import CoreLocation

@MainActor
class QuickInputPanelManager: NSObject {
    static let shared = QuickInputPanelManager()
    var panel: QuickInputPanel?
    
    func togglePanel() {
        if panel == nil {
            let contentView = QuickInputWindowView()
            let newPanel = QuickInputPanel(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 180),
                styleMask: [.titled, .fullSizeContentView, .hudWindow],
                backing: .buffered,
                defer: false
            )
            
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.titleVisibility = .hidden
            newPanel.titlebarAppearsTransparent = true
            newPanel.isMovableByWindowBackground = false
            newPanel.isReleasedWhenClosed = false
            newPanel.contentView = NSHostingView(rootView: contentView)
            newPanel.center()
            self.panel = newPanel
        }
        
        if let panel = panel {
            if panel.isVisible {
                panel.orderOut(nil)
            } else {
                panel.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                // Need to focus text field inside
            }
        }
    }
}

class QuickInputPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func cancelOperation(_ sender: Any?) {
        self.orderOut(nil)
    }
}

struct QuickInputWindowView: View {
    @State private var text: String = ""
    @State private var visibility: MemoVisibility = .private
    @State private var isSaving = false
    @State private var shouldFocusEditor = false
    @State private var isEditorFocused = false
    
    private var locationManager = LocationManager.shared
    @State private var currentLocation: Location?
    @State private var myRequestID: UUID?

    private var isLocalMode: Bool {
        AccountManager.shared.isLocalMode
    }

    private var activeAccountID: String {
        AccountManager.shared.activeAccount.map { AppState.accountIdentifier(for: $0) } ?? "local"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                QuickInputTextView(text: $text, shouldFocus: $shouldFocusEditor, isFocused: $isEditorFocused)
                    .frame(minHeight: 96, maxHeight: 96)

                if text.isEmpty && !isEditorFocused {
                    Text(String(localized: "Capture a thought... (Press Esc to cancel)", comment: "Placeholder for quick thought capture"))
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if let location = currentLocation {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 10))
                    
                    if let placeholder = location.placeholder, !placeholder.isEmpty {
                        Text(placeholder)
                    } else {
                        Text(String(format: "%.4f, %.4f", location.latitude, location.longitude))
                    }
                    
                    Button {
                        currentLocation = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }
            
            if let error = locationManager.error {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            HStack {
                Menu {
                    ForEach(MemoVisibility.allCases, id: \.self) { vis in
                        Button {
                            visibility = vis
                        } label: {
                            Label(vis.displayName, systemImage: vis.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: visibility.icon)
                        Text(visibility.displayName)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        let id = UUID()
                        myRequestID = id
                        locationManager.requestLocation(id: id)
                    } label: {
                        if locationManager.isFetching && locationManager.lastRequestID == myRequestID {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14))
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(currentLocation != nil ? .accentColor : .secondary)
                    
                    Button(String(localized: "Save", comment: "Label for save button")) {
                        saveMemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LiquidGlassTheme.colors.accent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.1) // Subtle dimming for QuickInput
            }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldFocusEditor = true
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if let newLocation = newLocation, locationManager.lastRequestID == myRequestID {
                withAnimation {
                    currentLocation = newLocation
                }
            }
        }
        .onDisappear {
            locationManager.clear()
        }
    }
    
    private func saveMemo() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSaving = true
        let tags = MemoUtility.extractTags(from: trimmed)
        
        Task {
            do {
                let tempId = "local_\(UUID().uuidString)"
                let newMemo = Memo(
                    name: tempId,
                    numericID: "",
                    content: trimmed,
                    visibility: visibility,
                    tags: tags,
                    attachments: [],
                    location: currentLocation,
                    accountID: activeAccountID,
                    isPendingSync: !isLocalMode
                )
                LocalDatabase.shared.context.insert(newMemo)
                
                if !isLocalMode {
                    let payload = CreateMemoPayload(
                        content: trimmed,
                        visibility: visibility.rawValue,
                        pinned: false,
                        tags: tags,
                        attachmentNames: [],
                        locationPlaceholder: currentLocation?.placeholder,
                        locationLatitude: currentLocation?.latitude,
                        locationLongitude: currentLocation?.longitude,
                        accountID: activeAccountID
                    )
                    let payloadData = try JSONEncoder().encode(payload)
                    let task = OutboxTask(type: .createMemo, payload: payloadData, memoId: tempId)
                    LocalDatabase.shared.context.insert(task)
                }
                try LocalDatabase.shared.context.save()
                SyncEngine.shared.triggerSync()
                
                await MainActor.run {
                    self.text = ""
                    self.currentLocation = nil
                    self.isSaving = false
                    QuickInputPanelManager.shared.togglePanel() // Hide
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                }
            }
        }
    }
}

private struct QuickInputTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    @Binding var isFocused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none

        let textView = QuickInputNativeTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.frame = NSRect(x: 0, y: 0, width: 0, height: scrollView.contentSize.height)
        textView.autoresizingMask = [.width]
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let isEditorFocused = (textView.window?.firstResponder === textView)
        if isFocused != isEditorFocused {
            DispatchQueue.main.async {
                isFocused = isEditorFocused
            }
        }

        if textView.string != text && !isEditorFocused {
            textView.string = text
        }

        if shouldFocus, let window = textView.window, window.firstResponder !== textView {
            window.makeFirstResponder(textView)
            DispatchQueue.main.async {
                shouldFocus = false
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickInputTextView

        init(parent: QuickInputTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class QuickInputNativeTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        let isPlainReturn = (event.keyCode == 36 || event.keyCode == 76) && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty
        if isPlainReturn {
            insertNewline(nil)
            return
        }
        super.keyDown(with: event)
    }
}
#else
@MainActor
class QuickInputPanelManager: NSObject {
    static let shared = QuickInputPanelManager()
    func togglePanel() {}
}
#endif
