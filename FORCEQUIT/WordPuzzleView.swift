import SwiftUI

/// Letter-cycling puzzle that asks the player to assemble the hidden word.
struct WordPuzzleView: View {
    /// Letters available to each slot while cycling through the answer.
    private let availableLetters = ["S", "N", "O", "C", "I", "A", "P"]
    /// Internal answer used to validate the puzzle.
    private let correctWord = "CINAI"

    /// Selected letter index for each answer slot.
    @State private var selectedIndexes = [0, 0, 0, 0, 0]
    /// Optional validation message shown after submission.
    @State private var resultMessage: String?
    /// Tracks whether the current answer is correct.
    @State private var isCorrect = false

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 16) {
                ForEach(selectedIndexes.indices, id: \.self) { index in
                    Button {
                        cycleLetter(at: index)
                    } label: {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                            .frame(width: 72, height: 88)
                            .overlay {
                                Text(availableLetters[selectedIndexes[index]])
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 150)
                }
            }

            Button {
                submitWord()
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

            if let resultMessage {
                Text(resultMessage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isCorrect ? .green : .red)
            }

            Spacer(minLength: 0)

            Text("Tap each box to cycle through the letters and form the hidden word.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(Color.white)
    }

    /// Builds the current word from the selected letter indexes.
    private var currentWord: String {
        selectedIndexes.map { availableLetters[$0] }.joined()
    }

    /// Advances a single answer slot to the next available letter.
    private func cycleLetter(at index: Int) {
        selectedIndexes[index] = (selectedIndexes[index] + 1) % availableLetters.count
        resultMessage = nil
    }

    /// Validates the current word and marks the challenge solved when correct.
    private func submitWord() {
        isCorrect = currentWord == correctWord
        if isCorrect {
            viewModel.markChallengeSolved(.challenge5)
        } else {
            viewModel.registerMistake()
        }
        resultMessage = isCorrect ? "Correct. The word is PANIC." : "Not quite. Try again."
    }
}
