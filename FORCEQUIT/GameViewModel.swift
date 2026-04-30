import AVFoundation
import Combine
import SwiftUI

/// Coordinates app window state, puzzle completion, countdown, and game audio.
final class GameViewModel: ObservableObject {
    /// Identifiers for each puzzle that must be solved to finish the game.
    enum Challenge: String, CaseIterable {
        case challenge1
        case challenge2
        case challenge3
        case challenge4
        case challenge5
    }

    /// Final game states used by the main view to show the ending overlay.
    enum GameOutcome {
        case bombDefused
        case bombGoesOff
    }

    /// Remaining countdown time in seconds.
    @Published var timeRemaining = 300
    /// Stack of open app identifiers in z-order.
    @Published var openApps: [String] = []
    /// Currently focused app identifier.
    @Published var activeApp: String? = nil
    /// Set of completed challenges.
    @Published var solvedChallenges: Set<Challenge> = []
    /// Final outcome once the player wins or the timer expires.
    @Published var gameOutcome: GameOutcome?
    /// Ensures the drag hint banner is shown only once.
    @Published private(set) var hasShownDragHint = false
    /// Remaining lives before the player instantly loses the game.
    @Published private(set) var livesRemaining = 3

    private let correctCode = "8671"
    private let maximumLives = 3

    private var timer: AnyCancellable?
    private var dragHintAudioPlayer: AVAudioPlayer?
    private var tickingAudioPlayer: AVAudioPlayer?
    private var phaseAudioPlayer: AVAudioPlayer?
    private var currentPhaseSoundName: String?
    private var crackAudioPlayer: AVAudioPlayer?

    init() {
        startGameAudio()
        startTimer()
    }

    /// Opens an app window and moves it to the top of the desktop stack.
    func openApp(_ app: String) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            openApps.removeAll { $0 == app }
            openApps.append(app)
            activeApp = app
        }
    }

    /// Closes an app window and updates focus to the next visible app if needed.
    func closeApp(_ app: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            openApps.removeAll { $0 == app }

            if activeApp == app {
                activeApp = openApps.last
            }
        }
    }

    /// Brings an already-open app window to the front.
    func focusApp(_ app: String) {
        guard openApps.contains(app) else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            openApps.removeAll { $0 == app }
            openApps.append(app)
            activeApp = app
        }
    }

    /// Marks a challenge as solved and ends the game if all puzzles are complete.
    func markChallengeSolved(_ challenge: Challenge) {
        guard !solvedChallenges.contains(challenge) else { return }

        solvedChallenges.insert(challenge)

        if solvedChallenges.count == Challenge.allCases.count {
            gameOutcome = .bombDefused
            timer?.cancel()
            stopGameAudio()
        }
    }

    /// Returns whether a specific challenge has already been completed.
    func isChallengeSolved(_ challenge: Challenge) -> Bool {
        solvedChallenges.contains(challenge)
    }

    /// Starts the global countdown timer that drives the pressure of the game.
    private func startTimer() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard self.gameOutcome == nil else { return }

                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    self.updateGameAudio(for: self.timeRemaining)
                }

                if self.timeRemaining == 0, self.gameOutcome == nil {
                    self.gameOutcome = .bombGoesOff
                    self.timer?.cancel()
                    self.stopGameAudio()
                }
            }
    }

    /// Validates the code entered in the keypad puzzle.
    func checkCode(_ input: String) -> Bool {
        let isCorrect = input == correctCode

        if isCorrect {
            markChallengeSolved(.challenge1)
        }

        return isCorrect
    }

    /// Consumes one life and triggers an immediate loss when no lives remain.
    func registerMistake() {
        guard gameOutcome == nil, livesRemaining > 0 else { return }

        livesRemaining -= 1
        playCrackSound()

        if livesRemaining == 0 {
            gameOutcome = .bombGoesOff
            timer?.cancel()
            stopGameAudio()
        }
    }

    /// Returns how many visual crack overlays should be visible in Safari.
    var visibleCrackCount: Int {
        maximumLives - livesRemaining
    }

    /// Determines whether the drag hint banner should be shown for the first app open.
    func shouldShowDragHint(for _: String) -> Bool {
        !hasShownDragHint
    }

    /// Records that the drag hint has already been displayed and plays its notification sound.
    func markDragHintShown(for _: String) {
        guard !hasShownDragHint else { return }

        hasShownDragHint = true

        playDragHintSoundPlaceholder()
    }

    /// Plays the notification sound used when the drag hint appears.
    private func playDragHintSoundPlaceholder() {
        guard let audioAsset = NSDataAsset(name: "notif_sound") else { return }

        do {
            dragHintAudioPlayer = try AVAudioPlayer(data: audioAsset.data)
            dragHintAudioPlayer?.prepareToPlay()
            dragHintAudioPlayer?.play()
        } catch {
            print("Failed to play notif_sound: \(error.localizedDescription)")
        }
    }

    /// Plays the glass crack sound each time the player loses a life.
    private func playCrackSound() {
        guard let audioAsset = NSDataAsset(name: "glasscrack") else { return }

        do {
            crackAudioPlayer = try AVAudioPlayer(data: audioAsset.data)
            crackAudioPlayer?.prepareToPlay()
            crackAudioPlayer?.play()
        } catch {
            print("Failed to play glasscrack: \(error.localizedDescription)")
        }
    }

    /// Starts the looping ambient audio layers for the active game session.
    private func startGameAudio() {
        tickingAudioPlayer = makeLoopingAudioPlayer(named: "timetick")
        tickingAudioPlayer?.play()
        updateGameAudio(for: timeRemaining)
    }

    /// Switches the looping phase audio based on the remaining time.
    private func updateGameAudio(for timeRemaining: Int) {
        guard gameOutcome == nil else { return }

        let nextPhaseSoundName = timeRemaining > 120 ? "3minsound" : "2minsound"
        guard currentPhaseSoundName != nextPhaseSoundName else { return }

        currentPhaseSoundName = nextPhaseSoundName
        phaseAudioPlayer?.stop()
        phaseAudioPlayer = makeLoopingAudioPlayer(named: nextPhaseSoundName)
        phaseAudioPlayer?.play()
    }

    /// Stops and clears any looping game audio.
    private func stopGameAudio() {
        tickingAudioPlayer?.stop()
        tickingAudioPlayer = nil
        phaseAudioPlayer?.stop()
        phaseAudioPlayer = nil
        currentPhaseSoundName = nil
    }

    /// Builds a looping audio player from a data asset.
    private func makeLoopingAudioPlayer(named assetName: String) -> AVAudioPlayer? {
        guard let audioAsset = NSDataAsset(name: assetName) else { return nil }

        do {
            let player = try AVAudioPlayer(data: audioAsset.data)
            player.numberOfLoops = -1
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to play \(assetName): \(error.localizedDescription)")
            return nil
        }
    }
}
