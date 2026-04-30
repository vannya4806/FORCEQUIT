import AVFoundation
import AVKit
import SwiftUI

/// Main menu that presents the animated title screen and starts the game.
struct MenuView: View {
    /// Starts a fresh play session when the menu button is pressed.
    let startGame: () -> Void

    private let title = "FORCE QUIT"

    /// Portion of the title currently visible during the typewriter animation.
    @State private var displayedTitle = ""
    /// Controls whether menu-only visual effects should continue running.
    @State private var animateBackground = false
    /// Toggles the brief glitch layers over the title.
    @State private var glitch = false
    /// Video player used for the animated menu background.
    @State private var player = MenuView.makePlayer()
    /// Preloaded audio data for the repeating click effect.
    @State private var clickSoundData = MenuView.loadAudioData(named: "mouseclick")
    /// Pool of active click players so overlapping sounds are not cut off.
    @State private var activeClickPlayers: [AVAudioPlayer] = []
    /// Task responsible for revealing the title one character at a time.
    @State private var typingTask: Task<Void, Never>?
    /// Task responsible for the accelerating click soundtrack.
    @State private var clickTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let player {
                MenuBackgroundVideo(player: player)
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.black, Color.gray.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(spacing: 30) {
                Spacer()

                ZStack {
                    Text(displayedTitle.isEmpty ? title : displayedTitle)
                        .font(.system(size: 142, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.16))
                        .offset(x: -4, y: -4)
                        .blur(radius: 8)

                    Text(displayedTitle.isEmpty ? title : displayedTitle)
                        .font(.system(size: 142, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.25), radius: 12)

                    if glitch {
                        Text(displayedTitle.isEmpty ? title : displayedTitle)
                            .font(.system(size: 142, weight: .black, design: .rounded))
                            .foregroundStyle(.black.opacity(0.1))
                            .offset(x: -3, y: 0)

                        Text(displayedTitle.isEmpty ? title : displayedTitle)
                            .font(.system(size: 142, weight: .black, design: .rounded))
                            .foregroundStyle(.black.opacity(0.7))
                            .offset(x: 3, y: 0)
                    }
                }
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    Button(action: {
                        startGame()
                    }) {
                        ZStack {
                            buttonLabel
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.90))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 320)

                Spacer()

                Text("Version 0.1")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 24)
            }
            .padding()
        }
        .ignoresSafeArea()
        .onAppear {
            animateBackground = true
            startGlitchTimer()
            startTypingEffect()
            startClickRamp()
            player?.play()
        }
        .onDisappear {
            animateBackground = false
            player?.pause()
            typingTask?.cancel()
            clickTask?.cancel()
            activeClickPlayers.forEach { $0.stop() }
            activeClickPlayers.removeAll()
        }
    }

    /// Reveals the title one character at a time to match the menu pacing.
    private func startTypingEffect() {
        typingTask?.cancel()
        displayedTitle = ""

        typingTask = Task {
            let characterDelay: UInt64 = 220_000_000

            for character in title {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    displayedTitle.append(character)
                }

                try? await Task.sleep(nanoseconds: characterDelay)
            }
        }
    }

    /// Plays repeating click sounds with an accelerating interval.
    private func startClickRamp() {
        clickTask?.cancel()

        clickTask = Task {
            var delay: UInt64 = 820_000_000
            let minimumDelay: UInt64 = 90_000_000

            while !Task.isCancelled {
                await MainActor.run {
                    playClickSound()
                }

                try? await Task.sleep(nanoseconds: delay)
                delay = max(minimumDelay, UInt64(Double(delay) * 0.84))
            }
        }
    }

    private func playClickSound() {
        activeClickPlayers.removeAll { !$0.isPlaying }

        guard let clickSoundData else { return }

        do {
            let player = try AVAudioPlayer(data: clickSoundData)
            player.prepareToPlay()
            player.play()
            activeClickPlayers.append(player)
        } catch {
            return
        }
    }

    /// Briefly offsets the title layers to create a periodic glitch effect.
    private func startGlitchTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            guard animateBackground else { return }

            withAnimation(.easeInOut(duration: 0.03)) {
                glitch = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.03)) {
                    glitch = false
                }
            }
        }
    }

    private var buttonLabel: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .font(.title2)
            Text("START")
                .font(.title2.bold())
        }
    }

    private static func makePlayer() -> AVPlayer? {
        guard let dataAsset = NSDataAsset(name: "menu_laptop") else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("menu_laptop.mp4")

        do {
            try dataAsset.data.write(to: tempURL, options: .atomic)
            let player = AVPlayer(url: tempURL)
            player.isMuted = false
            player.actionAtItemEnd = .none

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }

            return player
        } catch {
            return nil
        }
    }

    private static func loadAudioData(named assetName: String) -> Data? {
        guard let dataAsset = NSDataAsset(name: assetName) else {
            return nil
        }

        return dataAsset.data
    }
}

/// Wraps `AVPlayerView` so the menu can use a looping video background in SwiftUI.
struct MenuBackgroundVideo: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.player = player
        playerView.controlsStyle = .none
        playerView.videoGravity = .resizeAspectFill
        playerView.showsFullScreenToggleButton = false
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
