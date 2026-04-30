import AppKit
import SwiftUI

/// Browser-style container that hosts the interactive challenge tabs.
struct SafariView: View {
    /// Tabs representing each puzzle exposed through the fake browser UI.
    private enum ChallengeTab: String, CaseIterable, Identifiable {
        case challenge1
        case challenge2
        case challenge3
        case challenge4
        case challenge5

        var id: String { rawValue }

        /// Human-readable title shown in the tab strip.
        var title: String {
            switch self {
            case .challenge1: return "Challenge 1"
            case .challenge2: return "Challenge 2"
            case .challenge3: return "Challenge 3"
            case .challenge4: return "Challenge 4"
            case .challenge5: return "Challenge 5"
            }
        }

        /// Faux address shown in the browser's address field.
        var address: String {
            switch self {
            case .challenge1: return "All Numbers.forcequit"
            case .challenge2: return "Color Coded.forcequit"
            case .challenge3: return "Maze.forcequit"
            case .challenge4: return "Pitch.forcequit"
            case .challenge5: return "5 Words.forcequit"
            }
        }
    }

    /// Current visible drag offset applied to the browser window.
    @State private var settledOffset: CGSize = .zero
    /// Last committed drag offset used as the base for the next drag gesture.
    @State private var baseOffset: CGSize = .zero
    /// Raises the window z-index while the player is actively dragging it.
    @GestureState private var isDragging = false
    /// Currently selected challenge tab.
    @State private var activeTab: ChallengeTab? = .challenge1
    /// Tabs that are still open in the puzzle browser.
    @State private var openTabs: [ChallengeTab] = ChallengeTab.allCases
    /// Controls the intro scale and opacity animation for the browser window.
    @State private var hasAppeared = false
    /// Controls whether the first-time drag hint banner is visible.
    @State private var showDragHint = false
    /// Previous life count used to trigger the loss animation only when a life is consumed.
    @State private var previousLivesRemaining = 3
    /// Animates the lives indicator when the player loses a heart.
    @State private var animateLivesLoss = false

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            chromeBar
            tabStrip
            challengeContent
        }
        .frame(width: 900, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            if showDragHint {
                DragHintBanner {
                    showDragHint = false
                }
            }
        }
        .overlay {
            crackOverlay
        }
        .shadow(
            color: .black.opacity(isActive ? 0.24 : 0.1),
            radius: isDragging ? 18 : (isActive ? 14 : 8),
            x: 0,
            y: isDragging ? 14 : 8
        )
        .preferredColorScheme(.light)
        .offset(settledOffset)
        .scaleEffect(hasAppeared ? (isDragging ? 1.006 : 1) : 0.97)
        .opacity(hasAppeared ? (isActive ? 1 : 0.92) : 0)
        .onTapGesture {
            viewModel.focusApp("safari")
        }
        .onAppear {
            settledOffset = .zero
            baseOffset = settledOffset

            if viewModel.shouldShowDragHint(for: "safari") {
                showDragHint = true
                viewModel.markDragHintShown(for: "safari")
            }

            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                hasAppeared = true
            }
        }
        .onChange(of: viewModel.solvedChallenges) { _, solvedChallenges in
            for tab in openTabs where solvedChallenges.contains(challenge(for: tab)) {
                closeTab(tab)
            }
        }
        .onChange(of: viewModel.livesRemaining) { oldValue, newValue in
            guard newValue < oldValue else {
                previousLivesRemaining = newValue
                return
            }

            previousLivesRemaining = oldValue
            animateLivesLoss = true

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                animateLivesLoss = false
                previousLivesRemaining = newValue
            }
        }
    }

    /// Top browser chrome containing controls and the read-only address field.
    private var chromeBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    windowButton(color: Color(red: 1.0, green: 0.37, blue: 0.33), symbol: "xmark") {
                        viewModel.closeApp("safari")
                    }
                    windowButton(color: Color(white: 0.72))
                    windowButton(color: Color(white: 0.72))
                }
                .frame(width: 76, alignment: .leading)

                SafariNavigationControl()
                    .frame(width: 72, height: 28)

                Spacer(minLength: 12)

                SafariAddressField(
                    text: activeAddress,
                    placeholder: "Search or enter website name"
                )
                .frame(width: 360, height: 28)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    toolbarButton(systemName: "arrow.down.circle")
                    toolbarButton(systemName: "square.and.arrow.up")
                    toolbarButton(systemName: "plus")
                    toolbarButton(systemName: "rectangle.on.rectangle")
                }
                .frame(width: 116, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(alignment: .bottom) {
                Divider()
            }
            .contentShape(Rectangle())
            .highPriorityGesture(dragGesture)
        }
    }

    /// Remaining lives shown as hearts in the Safari toolbar.
    private var livesIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(index < viewModel.livesRemaining ? .red : Color.gray.opacity(0.8))
                    .scaleEffect(lossScale(for: index))
                    .opacity(lossOpacity(for: index))
                    .rotationEffect(.degrees(lossRotation(for: index)))
                    .animation(.spring(response: 0.24, dampingFraction: 0.52), value: animateLivesLoss)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    /// Enlarges and fades the heart that was just lost so the change is noticeable.
    private func lossScale(for index: Int) -> CGFloat {
        guard animateLivesLoss, index == viewModel.livesRemaining else { return 1 }
        return 1.55
    }

    /// Briefly fades the heart that was just lost during the damage animation.
    private func lossOpacity(for index: Int) -> Double {
        guard animateLivesLoss, index == viewModel.livesRemaining else { return 1 }
        return 0.35
    }

    /// Adds a small jolt rotation to the heart that was just lost.
    private func lossRotation(for index: Int) -> Double {
        guard animateLivesLoss, index == viewModel.livesRemaining else { return 0 }
        return index.isMultiple(of: 2) ? -16 : 16
    }

    /// Horizontal strip used to select the active puzzle tab.
    private var tabStrip: some View {
        GeometryReader { proxy in
            let tabCount = max(openTabs.count, 1)
            let totalWidth = max(proxy.size.width - 8, 0)
            let tabWidth = totalWidth / CGFloat(tabCount)

            HStack(spacing: 0) {
                ForEach(Array(openTabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        activeTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(activeTab == tab ? Color.accentColor : .secondary)

                            Text(tab.title)
                                .font(.system(size: 12, weight: activeTab == tab ? .semibold : .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            activeTab == tab
                                ? Color.white
                                : Color(red: 0.93, green: 0.93, blue: 0.94)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: tabWidth)
                    .overlay(alignment: .leading) {
                        if index != 0 {
                            Rectangle()
                                .fill(Color.black.opacity(0.08))
                                .frame(width: 1, height: 20)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .frame(height: 48)
        .background(Color(red: 0.95, green: 0.95, blue: 0.96))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    /// Progressive crack overlays that appear as lives are lost.
    private var crackOverlay: some View {
        ZStack {
            if viewModel.visibleCrackCount >= 1 {
                Image("cracking")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320)
                    .rotationEffect(.degrees(12))
                    .opacity(0.95)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: -64, y: 20)
            }

            if viewModel.visibleCrackCount >= 2 {
                Image("cracking")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 360)
                    .rotationEffect(.degrees(194))
                    .opacity(0.98)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .offset(x: -30, y: 48)
            }

            livesIndicator
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 22)
                .padding(.bottom, 20)
        }
        .allowsHitTesting(false)
    }

    /// Displays the content for the currently selected puzzle tab.
    @ViewBuilder
    private var challengeContent: some View {
        Group {
            if let activeTab {
                switch activeTab {
                case .challenge1:
                    NumberPuzzleView(viewModel: viewModel)
                case .challenge2:
                    CablePuzzleView(viewModel: viewModel)
                case .challenge3:
                    LabyrinthView(viewModel: viewModel)
                case .challenge4:
                    PitchPuzzleView(viewModel: viewModel)
                case .challenge5:
                    WordPuzzleView(viewModel: viewModel)
                }
            } else {
                emptyTabState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    /// Fallback view shown after all challenge tabs have been closed.
    private var emptyTabState: some View {
        ContentUnavailableView(
            "No Open Challenges",
            systemImage: "square.slash",
            description: Text("Semua tab challenge yang aktif sudah tertutup.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Address text for the active tab, or a blank placeholder when no tab is open.
    private var activeAddress: String {
        activeTab?.address ?? "about:blank"
    }

    /// Small toolbar button used in the fake browser chrome.
    private func toolbarButton(systemName: String) -> some View {
        Button {
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.85))
    }

    /// Reusable traffic-light window button used in the custom title bar.
    private func windowButton(
        color: Color,
        symbol: String? = nil,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(color)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Lets the player drag the Safari window around the desktop.
    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                withTransaction(Transaction(animation: nil)) {
                    let dx = value.location.x - value.startLocation.x
                    let dy = value.location.y - value.startLocation.y
                    settledOffset = CGSize(
                        width: baseOffset.width + dx,
                        height: baseOffset.height + dy
                    )
                }
            }
            .onEnded { value in
                let dx = value.location.x - value.startLocation.x
                let dy = value.location.y - value.startLocation.y
                let final = CGSize(
                    width: (baseOffset.width + dx).rounded(),
                    height: (baseOffset.height + dy).rounded()
                )
                settledOffset = final
                baseOffset = final
            }
    }

    /// Removes a tab after its corresponding challenge has been solved.
    private func closeTab(_ tab: ChallengeTab) {
        guard openTabs.contains(tab) else { return }

        withAnimation(.easeInOut(duration: 0.28)) {
            let remainingTabs = openTabs.filter { $0 != tab }
            openTabs = remainingTabs

            if activeTab == tab {
                activeTab = remainingTabs.first
            }
        }
    }

    /// Maps a tab identifier to the matching game challenge enum.
    private func challenge(for tab: ChallengeTab) -> GameViewModel.Challenge {
        switch tab {
        case .challenge1: return .challenge1
        case .challenge2: return .challenge2
        case .challenge3: return .challenge3
        case .challenge4: return .challenge4
        case .challenge5: return .challenge5
        }
    }

    /// Returns whether this window is currently the focused app.
    private var isActive: Bool {
        viewModel.activeApp == "safari"
    }
}

/// Read-only address field wrapper for the faux Safari chrome.
private struct SafariAddressField: NSViewRepresentable {
    /// Current address string shown in the field.
    let text: String
    /// Placeholder shown when no address is available.
    let placeholder: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.appearance = NSAppearance(named: .aqua)
        field.isEditable = false
        field.isSelectable = true
        field.focusRingType = .none
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.appearance = NSAppearance(named: .aqua)
        nsView.stringValue = text
        nsView.placeholderString = placeholder
    }
}

/// Read-only navigation control wrapper for the faux Safari toolbar.
private struct SafariNavigationControl: NSViewRepresentable {
    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: ["", ""], trackingMode: .momentary, target: nil, action: nil)
        control.appearance = NSAppearance(named: .aqua)
        control.segmentStyle = .separated
        control.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil), forSegment: 0)
        control.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil), forSegment: 1)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        nsView.appearance = NSAppearance(named: .aqua)
    }
}
