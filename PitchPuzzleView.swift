import SwiftUI

/// Slider puzzle that snaps each pitch handle to its target height.
struct PitchPuzzleView: View {
    /// Full height of each vertical slider track.
    private let trackHeight: CGFloat = 250
    /// Allowed snap positions for each pitch handle.
    private let markerOffsets: [CGFloat] = [20, 90, 160, 230]
    /// Target snap positions required to solve the puzzle.
    private let targetOffsets: [CGFloat] = [20, 160, 90, 20]

    /// Current snapped offsets for the draggable handles.
    @State private var handleOffsets: [CGFloat] = [230, 230, 230, 230]
    /// Base offsets captured when each drag gesture begins.
    @State private var dragStartOffsets: [CGFloat] = [230, 230, 230, 230]

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 44) {
                ForEach(handleOffsets.indices, id: \.self) { index in
                    pitchSlider(at: index)
                }
            }
            .padding(.top, 36)
            .padding(.bottom, 40)

            Button {
                submitAnswer()
            } label: {
                Text("Submit")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 120, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 16)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .background(Color.white)
    }

    /// Renders a single draggable pitch slider.
    private func pitchSlider(at index: Int) -> some View {
        ZStack {
            Capsule()
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.28))
                .frame(width: 12, height: trackHeight)
                .overlay {
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }

            ForEach(markerOffsets, id: \.self) { marker in
                Image(systemName: "minus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .offset(y: marker - trackHeight / 2)
            }

            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 52, height: 28)
                .overlay {
                    Capsule()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
                .offset(y: handleOffsets[index] - trackHeight / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let rawOffset = dragStartOffsets[index] + value.translation.height
                            handleOffsets[index] = snappedOffset(for: rawOffset)
                        }
                        .onEnded { _ in
                            dragStartOffsets[index] = handleOffsets[index]
                        }
                )
        }
        .frame(width: 64, height: trackHeight + 16)
        .overlay(alignment: .bottom) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .offset(y: 40)
        }
    }

    /// Snaps a dragged value to the nearest valid marker on the track.
    private func snappedOffset(for rawOffset: CGFloat) -> CGFloat {
        let clamped = min(max(rawOffset, markerOffsets.first ?? 0), markerOffsets.last ?? trackHeight)
        return markerOffsets.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? clamped
    }

    /// Validates all slider positions against the target solution.
    private func submitAnswer() {
        let isCorrect = zip(handleOffsets, targetOffsets).allSatisfy { current, target in
            abs(current - target) < 0.1
        }

        if isCorrect {
            viewModel.markChallengeSolved(.challenge4)
        } else {
            viewModel.registerMistake()
        }
    }
}
