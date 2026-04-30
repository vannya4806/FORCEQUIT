import SwiftUI

/// Routes the user between the main menu and the active game session.
struct ContentView: View {
    /// Tracks whether the player has started the game from the menu screen.
    @State private var gameStarted = false

    var body: some View {
        if gameStarted {
            GameView()
        } else {
            MenuView(startGame: {
                gameStarted = true
            })
        }
    }
}

#Preview {
    ContentView()
}
