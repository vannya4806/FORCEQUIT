import SwiftUI

/// Hidden-path maze puzzle controlled through directional buttons.
struct LabyrinthView: View {
    /// Coordinate used to track the player's location in the grid.
    private struct GridPosition: Equatable {
        let row: Int
        let column: Int
    }

    /// Number of rows in the maze grid.
    private let rows = 8
    /// Number of columns in the maze grid.
    private let columns = 7
    /// Starting position of the player token.
    private let start = GridPosition(row: 7, column: 6)
    /// Target position that completes the puzzle.
    private let destination = GridPosition(row: 5, column: 2)

    private let blockedCells: Set<String> = [
        "0-4",
        "1-2",
        "2-2", "2-4",
        "3-0", "3-4",
        "4-2", "4-4",
        "5-3", "5-5",
        "6-2", "6-4",
        "7-0", "7-1", "7-2"
    ]

    /// Current player position in the maze.
    @State private var currentPosition = GridPosition(row: 7, column: 6)
    /// Tracks whether the puzzle has already been completed.
    @State private var didWin = false
    /// Instruction or validation message shown below the maze.
    @State private var statusMessage = "Find the hidden path to the target."
    /// Size of each maze cell.
    private let cellSize: CGFloat = 40

    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 24) {
                gridView
                movementControls
            }

            Spacer(minLength: 0)

            Text(statusMessage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(didWin ? .green : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 28)
        .padding(.top, 66)
        .padding(.bottom, 16)
        .background(Color.white)
    }

    /// Visible maze board with the player token and destination marker.
    private var gridView: some View {
        let columnsLayout = Array(repeating: GridItem(.fixed(cellSize), spacing: 0), count: columns)

        return LazyVGrid(columns: columnsLayout, spacing: 0) {
            ForEach(0..<(rows * columns), id: \.self) { index in
                let row = index / columns
                let column = index % columns
                let position = GridPosition(row: row, column: column)

                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: cellSize, height: cellSize)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 1)
                        )

                    if position == destination {
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 4, height: 4)
                            )
                    }

                    if position == currentPosition {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 18, height: 18)
                    }
                }
            }
        }
    }

    /// Directional control pad used to move through the maze.
    private var movementControls: some View {
        VStack(spacing: 10) {
            moveButton(title: "Up") {
                move(rowOffset: -1, columnOffset: 0)
            }

            HStack(spacing: 8) {
                moveButton(title: "Left") {
                    move(rowOffset: 0, columnOffset: -1)
                }

                moveButton(title: "Down") {
                    move(rowOffset: 1, columnOffset: 0)
                }

                moveButton(title: "Right") {
                    move(rowOffset: 0, columnOffset: 1)
                }
            }
        }
        .frame(width: 170)
    }

    /// Reusable button used by the movement control pad.
    private func moveButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black)
                )
        }
        .buttonStyle(.plain)
    }

    /// Attempts to move the player and validates blocked or winning states.
    private func move(rowOffset: Int, columnOffset: Int) {
        guard !didWin else { return }

        let nextPosition = GridPosition(
            row: currentPosition.row + rowOffset,
            column: currentPosition.column + columnOffset
        )

        guard isInsideGrid(nextPosition), !isBlocked(nextPosition) else {
            statusMessage = "That direction is blocked."
            viewModel.registerMistake()
            return
        }

        currentPosition = nextPosition

        if currentPosition == destination {
            didWin = true
            statusMessage = "Challenge complete."
            viewModel.markChallengeSolved(.challenge3)
        } else {
            statusMessage = "Keep moving."
        }
    }

    /// Returns whether a position is still inside the maze bounds.
    private func isInsideGrid(_ position: GridPosition) -> Bool {
        position.row >= 0 && position.row < rows && position.column >= 0 && position.column < columns
    }

    /// Returns whether a position is part of the hidden blocked path.
    private func isBlocked(_ position: GridPosition) -> Bool {
        blockedCells.contains("\(position.row)-\(position.column)")
    }
}
