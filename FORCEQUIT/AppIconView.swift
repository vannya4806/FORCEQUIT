import SwiftUI

/// Dock icon button that opens an app window from the desktop.
struct AppIconView: View {
    private let iconFrame: CGFloat = 52
    private let imageFrame: CGFloat = 46

    /// Accessibility and display name for the dock item.
    let name: String
    /// Asset name used to render the app icon.
    let icon: String
    /// Action fired when the dock icon is clicked.
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageFrame, height: imageFrame)
                    .frame(width: iconFrame, height: iconFrame)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}
