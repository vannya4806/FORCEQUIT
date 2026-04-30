import SwiftUI

/// Static call log clue window that can be dragged and focused.
struct CallLogAppView: View {
    /// Current visible drag offset applied to the window.
    @State private var settledOffset: CGSize = .zero
    /// Last committed drag offset used as the base for the next drag gesture.
    @State private var baseOffset: CGSize = .zero
    /// Controls whether the first-time drag hint banner is visible.
    @State private var showDragHint = false
    /// Raises the window z-index while the player is actively dragging it.
    @GestureState private var isDragging = false

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                titleBar

                Image("call_log")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
            }
            .frame(width: 220, height: 450)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if showDragHint {
                    DragHintBanner {
                        showDragHint = false
                    }
                }
            }
            .shadow(color: .black.opacity(0.22), radius: 24, y: 16)
            .onAppear {
                settledOffset = CGSize(width: 0, height: 0)
                baseOffset = settledOffset

                if viewModel.shouldShowDragHint(for: "calllog") {
                    showDragHint = true
                    viewModel.markDragHintShown(for: "calllog")
                }
            }
            .animation(nil, value: settledOffset)
            .offset(settledOffset)
            .zIndex(isDragging ? 100 : 0)
            .opacity(isActive ? 1 : 0.92)
            .onTapGesture {
                viewModel.focusApp("calllog")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Faux macOS title bar with close control and drag gesture support.
    private var titleBar: some View {
        HStack {
            HStack(spacing: 8) {
                windowButton(color: Color(red: 1.0, green: 0.37, blue: 0.33), symbol: "xmark") {
                    viewModel.closeApp("calllog")
                }

                windowButton(color: Color(white: 0.72))

                windowButton(color: Color(white: 0.72))
            }

            Spacer()
        }
        .overlay {
            Text("Call")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isActive ? Color(white: 0.94) : Color(white: 0.9))
        .contentShape(Rectangle())
        .highPriorityGesture(dragGesture)
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

    /// Lets the player move the window freely across the desktop.
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

    /// Returns whether this window is currently the focused app.
    private var isActive: Bool {
        viewModel.activeApp == "calllog"
    }
}
