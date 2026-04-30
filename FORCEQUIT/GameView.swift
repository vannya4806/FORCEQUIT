import AVFoundation
import AVKit
import SwiftUI

/// Presents the desktop scene, active apps, countdown, and final outcome overlays.
struct GameView: View {
    /// Visual stages used when presenting the ending overlay.
    private enum OutcomeOverlayPhase {
        case freeze
        case black
        case impact
        case result
        case glitch
        case fadeOut
    }

    /// Distinguishes whether the typewriter animation is filling the headline or detail text.
    private enum OutcomeTextTarget {
        case headline
        case detail
    }

    /// Shared game state for the current play session.
    @StateObject private var viewModel = GameViewModel()
    /// Caches the ending state once the overlay sequence starts.
    @State private var presentedOutcome: GameViewModel.GameOutcome?
    @State private var outcomeOverlayPhase: OutcomeOverlayPhase = .black
    @State private var outcomeHeadline = ""
    @State private var outcomeDetail = ""
    @State private var outcomeTask: Task<Void, Never>?
    @State private var typingAudioPlayer: AVAudioPlayer?
    @State private var impactAudioPlayer: AVAudioPlayer?
    @State private var beepAudioPlayer: AVAudioPlayer?
    @State private var explosionAudioPlayer: AVAudioPlayer?
    @State private var impactVideoPlayer: AVPlayer?
    @State private var glitchVideoPlayer: AVPlayer?
    @State private var panicPulse = false
    @State private var fadeOutOpacity = 0.0
    @State private var resultContentOpacity = 1.0

    var body: some View {
        ZStack {
            Image("desktop_wallpaper")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            desktopSurface

            if let gameOutcome = presentedOutcome {
                outcomeOverlay(for: gameOutcome)
                    .zIndex(999)
            }
        }
        .onChange(of: viewModel.gameOutcome) { _, newOutcome in
            guard let newOutcome else { return }
            startOutcomeSequence(for: newOutcome)
        }
        .onChange(of: viewModel.timeRemaining) { _, newValue in
            updatePanicPulse(for: newValue)
        }
        .onAppear {
            updatePanicPulse(for: viewModel.timeRemaining)
        }
        .onDisappear {
            outcomeTask?.cancel()
            stopOutcomeAudio()
        }
    }

    /// Formats the remaining countdown time as minutes and seconds.
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Floating countdown display shown at the top of the desktop.
    private var timerView: some View {
        Text(formattedTime(viewModel.timeRemaining))
            .font(.system(size: 45, weight: .heavy, design: .monospaced))
            .foregroundColor(.red)
            .padding(.horizontal, 40)
            .padding(.vertical, 25)
            .background(Color.black)
            .cornerRadius(10)
            .shadow(color: .red.opacity(0.6), radius: 8, x: 0, y: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 50)
    }

    /// Main desktop surface containing wallpaper, windows, dock, and overlays.
    private var desktopSurface: some View {
        ZStack {
            Image("desktop_wallpaper")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ForEach(viewModel.openApps, id: \.self) { app in
                windowView(for: app)
                    .zIndex(viewModel.activeApp == app ? 1 : 0.5)
            }

            DesktopView(viewModel: viewModel)
                .zIndex(2)

            timerView
                .zIndex(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .overlay {
            if shouldShowPanicFrame {
                panicFrameOverlay
            }
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 16)
        .safeAreaPadding(EdgeInsets(top: 0, leading: 28, bottom: 24, trailing: 28))
    }

    /// Resolves an app identifier into its corresponding window view.
    @ViewBuilder
    private func windowView(for app: String) -> some View {
        switch app {
        case "calllog":
            CallLogAppView(viewModel: viewModel)
        case "safari":
            SafariView(viewModel: viewModel)
        case "music":
            MusicAppView(viewModel: viewModel)
        case "calendar":
            CalendarAppView(viewModel: viewModel)
        case "reminder":
            ReminderAppView(viewModel: viewModel)
        case "fruit":
            FruitAppView(viewModel: viewModel)
        default:
            EmptyView()
        }
    }

    /// Full-screen ending overlay shown when the player wins or loses.
    private func outcomeOverlay(for gameOutcome: GameViewModel.GameOutcome) -> some View {
        ZStack {
            overlayBackground(for: gameOutcome)

            if shouldShowOutcomeText(for: gameOutcome) {
                VStack(spacing: 14) {
                    Spacer()

                    Text(outcomeHeadline)
                        .font(.system(size: 46, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 820)

                    Text(outcomeDetail)
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.86))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 860)

                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 56)
                .opacity(resultContentOpacity)
            }

            if outcomeOverlayPhase == .fadeOut {
                Color.black
                    .opacity(fadeOutOpacity)
                    .ignoresSafeArea()
            }
        }
    }

    /// Chooses the proper background for each end-state phase.
    @ViewBuilder
    private func overlayBackground(for gameOutcome: GameViewModel.GameOutcome) -> some View {
        switch gameOutcome {
        case .bombGoesOff:
            switch outcomeOverlayPhase {
            case .freeze:
                Color.clear
                    .ignoresSafeArea()
            case .black, .fadeOut:
                Color.black
                    .ignoresSafeArea()
            case .result:
                ZStack {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    Image("brokenmirror")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            case .impact:
                if let impactVideoPlayer {
                    OutcomeVideoView(player: impactVideoPlayer)
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
            case .glitch:
                if let glitchVideoPlayer {
                    OutcomeVideoView(player: glitchVideoPlayer)
                        .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
            }
        case .bombDefused:
            switch outcomeOverlayPhase {
            case .freeze:
                Color.black.opacity(0.02)
                    .ignoresSafeArea()
            case .black, .result, .fadeOut, .glitch:
                Color.black
                    .ignoresSafeArea()
            case .impact:
                EmptyView()
            }
        }
    }

    /// Overlay shown while the win state freezes the UI before cutting to black.
    private var freezeOverlay: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }

    /// Determines whether the end-state text should currently be visible.
    private func shouldShowOutcomeText(for gameOutcome: GameViewModel.GameOutcome) -> Bool {
        switch gameOutcome {
        case .bombGoesOff:
            outcomeOverlayPhase == .result
        case .bombDefused:
            outcomeOverlayPhase == .result || outcomeOverlayPhase == .fadeOut
        }
    }

    /// Enables the red panic frame during the last minute of the countdown.
    private var shouldShowPanicFrame: Bool {
        viewModel.gameOutcome == nil && viewModel.timeRemaining <= 60
    }

    /// Pulsing frame effect used to increase urgency near the end of the timer.
    private var panicFrameOverlay: some View {
        ZStack {
            VStack {
                horizontalEdgeGlow
                    .offset(y: -44)

                Spacer()

                horizontalEdgeGlow
                    .offset(y: 44)
            }

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    Color.red.opacity(panicPulse ? 0.92 : 0.52),
                    lineWidth: panicPulse ? 5 : 3
                )
                .blur(radius: panicPulse ? 6 : 3)
        }
        .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: panicPulse)
        .allowsHitTesting(false)
    }

    /// Horizontal glow element reused on the top and bottom edges of the panic frame.
    private var horizontalEdgeGlow: some View {
        LinearGradient(
            colors: [
                .red.opacity(0),
                .red.opacity(panicPulse ? 0.95 : 0.58),
                .red.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 54)
        .blur(radius: 16)
    }

    /// Starts or stops the panic pulse based on the remaining time.
    private func updatePanicPulse(for timeRemaining: Int) {
        if timeRemaining <= 60, viewModel.gameOutcome == nil {
            panicPulse = true
        } else {
            panicPulse = false
        }
    }

    /// Kicks off the animated end-state presentation once the game is over.
    private func startOutcomeSequence(for outcome: GameViewModel.GameOutcome) {
        guard presentedOutcome == nil else { return }

        outcomeTask?.cancel()
        stopOutcomeAudio()

        presentedOutcome = outcome
        outcomeOverlayPhase = outcome == .bombDefused ? .freeze : .black
        outcomeHeadline = ""
        outcomeDetail = ""
        fadeOutOpacity = 0
        resultContentOpacity = 1
        impactVideoPlayer = nil
        glitchVideoPlayer = nil

        outcomeTask = Task { @MainActor in
            switch outcome {
            case .bombGoesOff:
                viewModel.timeRemaining = 0
                outcomeOverlayPhase = .black

                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }

                outcomeOverlayPhase = .result
                playImpactSound()
                await playTypingSequence(
                    headline: "BOMB EXPLODED......",
                    detail: ""
                )
                guard !Task.isCancelled else { return }

                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }

                if let impactMedia = await makeVideoPlayer(named: "glassbreak", isMuted: true) {
                    impactVideoPlayer = impactMedia.player
                    outcomeOverlayPhase = .impact
                    playExplosionSound()
                    impactMedia.player.play()

                    try? await Task.sleep(for: .seconds(impactMedia.duration))
                    guard !Task.isCancelled else { return }
                }

                impactVideoPlayer?.pause()
                impactVideoPlayer = nil

                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }

                if let glitchMedia = await makeVideoPlayer(named: "videoglitch", isMuted: false) {
                    glitchVideoPlayer = glitchMedia.player
                    outcomeOverlayPhase = .glitch
                    glitchMedia.player.play()

                    try? await Task.sleep(for: .seconds(glitchMedia.duration))
                    guard !Task.isCancelled else { return }
                }

                glitchVideoPlayer?.pause()
                glitchVideoPlayer = nil
                outcomeOverlayPhase = .fadeOut

                withAnimation(.easeInOut(duration: 3)) {
                    fadeOutOpacity = 1
                }

                try? await Task.sleep(for: .seconds(3))
                stopOutcomeAudio()
            case .bombDefused:
                viewModel.timeRemaining = 0
                viewModel.closeApp("safari")
                outcomeOverlayPhase = .black

                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }

                outcomeOverlayPhase = .result

                await playTypingSequence(
                    headline: "OK. YOU WIN.",
                    detail: "BUT YOU WON'T BE THIS LUCKY AGAIN."
                )
                guard !Task.isCancelled else { return }

                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }

                outcomeOverlayPhase = .fadeOut
                withAnimation(.easeInOut(duration: 3)) {
                    resultContentOpacity = 0
                    fadeOutOpacity = 1
                }
                await fadeOutWinAudio(duration: 3)
            }
        }
    }

    /// Types the outcome headline and detail while looping keyboard audio.
    @MainActor
    private func playTypingSequence(headline: String, detail: String) async {
        playTypingLoop()
        defer {
            stopTypingLoop()
        }

        await typeText(headline, target: .headline, characterDelay: 45_000_000)
        guard !Task.isCancelled else { return }

        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }

        await typeText(detail, target: .detail, characterDelay: 30_000_000)
    }

    /// Appends text one character at a time into the requested ending label.
    @MainActor
    private func typeText(
        _ text: String,
        target: OutcomeTextTarget,
        characterDelay: UInt64
    ) async {
        switch target {
        case .headline:
            outcomeHeadline = ""
        case .detail:
            outcomeDetail = ""
        }

        for character in text {
            guard !Task.isCancelled else { return }

            switch target {
            case .headline:
                outcomeHeadline.append(character)
            case .detail:
                outcomeDetail.append(character)
            }

            try? await Task.sleep(nanoseconds: characterDelay)
        }
    }

    /// Starts the looping typing sound used during the ending text animation.
    private func playTypingLoop() {
        typingAudioPlayer = makeAudioPlayer(named: "typing", loops: -1, volume: 0.18)
        typingAudioPlayer?.play()
    }

    /// Stops and clears the typing loop audio.
    private func stopTypingLoop() {
        typingAudioPlayer?.stop()
        typingAudioPlayer = nil
    }

    /// Plays the glass impact sound for the failure ending.
    private func playImpactSound() {
        impactAudioPlayer = makeAudioPlayer(named: "pecah", loops: 0)
        impactAudioPlayer?.play()
    }

    /// Plays the soft terminal-like beep used during the freeze phase.
    private func playBeepTone() {
        beepAudioPlayer = makeAudioPlayer(named: "beep", loops: 0, volume: 0.18)
        beepAudioPlayer?.play()
    }

    /// Plays the explosion sting after the warning text appears.
    private func playExplosionSound() {
        explosionAudioPlayer = makeAudioPlayer(named: "explode", loops: 0, volume: 0.92)
        explosionAudioPlayer?.play()
    }

    /// Stops any audio dedicated to the ending overlay.
    private func stopOutcomeAudio() {
        stopTypingLoop()
        impactAudioPlayer?.stop()
        impactAudioPlayer = nil
        beepAudioPlayer?.stop()
        beepAudioPlayer = nil
        explosionAudioPlayer?.stop()
        explosionAudioPlayer = nil
        impactVideoPlayer?.pause()
        impactVideoPlayer = nil
        glitchVideoPlayer?.pause()
        glitchVideoPlayer = nil
        fadeOutOpacity = 0
        resultContentOpacity = 1
    }

    /// Fades out the win-scene audio layers before the screen goes fully black.
    @MainActor
    private func fadeOutWinAudio(duration: Double) async {
        let steps = 18
        let delay = UInt64((duration / Double(steps)) * 1_000_000_000)

        for step in stride(from: steps, through: 0, by: -1) {
            guard !Task.isCancelled else { return }

            let progress = Float(step) / Float(steps)
            typingAudioPlayer?.volume = 0.18 * progress

            try? await Task.sleep(nanoseconds: delay)
        }

        stopOutcomeAudio()
    }

    /// Creates a full-screen video player from a bundled data asset and returns its duration.
    private func makeVideoPlayer(named assetName: String, isMuted: Bool) async -> (player: AVPlayer, duration: Double)? {
        guard let dataAsset = NSDataAsset(name: assetName) else { return nil }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(assetName)-ending.mp4")

        do {
            try dataAsset.data.write(to: tempURL, options: .atomic)
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            let player = AVPlayer(url: tempURL)
            player.isMuted = isMuted
            return (player, max(CMTimeGetSeconds(duration), 0.1))
        } catch {
            return nil
        }
    }

    /// Builds a one-shot or looping audio player from a bundled data asset.
    private func makeAudioPlayer(named assetName: String, loops: Int, volume: Float = 1) -> AVAudioPlayer? {
        guard let dataAsset = NSDataAsset(name: assetName) else { return nil }

        do {
            let player = try AVAudioPlayer(data: dataAsset.data)
            player.numberOfLoops = loops
            player.volume = volume
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
}

/// Wraps `AVPlayerView` so full-screen ending videos can play inside SwiftUI.
private struct OutcomeVideoView: NSViewRepresentable {
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
