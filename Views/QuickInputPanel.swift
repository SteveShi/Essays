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
                styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .hudWindow],
                backing: .buffered,
                defer: false
            )
            
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.titleVisibility = .hidden
            newPanel.titlebarAppearsTransparent = true
            newPanel.isMovableByWindowBackground = true
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
    @FocusState private var isFocused: Bool
    
    private var locationManager = LocationManager.shared
    @State private var currentLocation: Location?
    @State private var myRequestID: UUID?
    
    var body: some View {
        VStack(spacing: 12) {
            TextField(String(localized: "Capture a thought... (Press Esc to cancel)", comment: "Placeholder for quick thought capture"), text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .lineLimit(1...8)
                .focused($isFocused)
                .padding()
            
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
                    .keyboardShortcut(.return, modifiers: .command)
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
                isFocused = true
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
                _ = try await MemosAPIClient.shared.createMemo(
                    content: trimmed,
                    visibility: visibility,
                    tags: tags,
                    attachmentNames: [],
                    location: currentLocation
                )
                
                await MainActor.run {
                    self.text = ""
                    self.currentLocation = nil
                    self.isSaving = false
                    QuickInputPanelManager.shared.togglePanel() // Hide
                    
                    // Fire refresh in background if possible
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    // Ideally show error toast
                }
            }
        }
    }
}
#else
@MainActor
class QuickInputPanelManager: NSObject {
    static let shared = QuickInputPanelManager()
    func togglePanel() {}
}
#endif
