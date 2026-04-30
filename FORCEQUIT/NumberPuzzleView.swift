import SwiftUI

/// Keypad puzzle that validates the four-digit code needed for the first challenge.
struct NumberPuzzleView: View {
    @ObservedObject var viewModel: GameViewModel

    /// Digits currently entered by the player.
    @State private var input: [String] = []
    /// Optional message used to show success or failure after submission.
    @State private var feedbackMessage: String?

    /// Keys rendered in the keypad grid.
    private let keypad = [
        "1","2","3",
        "4","5","6",
        "7","8","9",
        "*","0","#"
    ]

    var body: some View {
        HStack(spacing: 32) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(72)), count: 3), spacing: 22) {
                ForEach(keypad, id: \.self) { key in
                    Button {
                        pressKey(key)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Circle()
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                }
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

                            keypadLabel(for: key)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    ForEach(0..<4) { index in
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 52, height: 52)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .overlay {
                                if index < input.count {
                                    keypadLabel(for: input[index])
                                } else {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary.opacity(0.45))
                                }
                            }
                    }
                }

                Button(action: {
                    let code = input.joined()
                    if !viewModel.checkCode(code) {
                        feedbackMessage = "CODE WRONG"
                        input.removeAll()
                        viewModel.registerMistake()
                    } else {
                        feedbackMessage = "ACCESS GRANTED"
                    }
                }) {
                    Text("Submit")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 36)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.leading, 60)

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(feedbackMessage == "ACCESS GRANTED" ? .green : .red)
                        .padding(.leading, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.leading, 56)
        .padding(.trailing, 24)
        .padding(.vertical, 24)
        .offset(x: -24)
    }

    /// Returns the correct visual treatment for a keypad symbol.
    @ViewBuilder
    private func keypadLabel(for key: String) -> some View {
        switch key {
        case "*":
            Image(systemName: "asterisk")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)
        case "#":
            Image(systemName: "number")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
        default:
            Text(key)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    /// Appends a key to the input while respecting the four-digit limit.
    private func pressKey(_ key: String) {
        if feedbackMessage == "CODE WRONG" {
            feedbackMessage = nil
        }

        if input.count < 4 {
            input.append(key)
        }
    }
}
