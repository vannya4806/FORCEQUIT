import SwiftUI

/// Renders the mock macOS menu bar and dock used to launch puzzle windows.
struct DesktopView: View {
    @ObservedObject var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 0) {
            menuBar

            Spacer(minLength: 0)

            dock
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Faux menu bar shown at the top of the desktop scene.
    private var menuBar: some View {
        HStack(spacing: 25) {
            Image(systemName: "apple.logo")
                .font(.system(size: 14, weight: .semibold))
            Text(activeAppDisplayName)
                .font(.system(size: 14, weight: .semibold))

            Text("File")
                .font(.system(size: 13))
            Text("Edit")
                .font(.system(size: 13))
            Text("View")
                .font(.system(size: 13))
            Text("Find")
                .font(.system(size: 13))
            Spacer()

            HStack(spacing: 17) {
                Image(systemName: "wifi")
                Image(systemName: "battery.50")
                Image(systemName: "magnifyingglass")
                Text("Thu 8 May")
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text("12.24")
                    .font(.system(size: 13))
                    .lineLimit(1)
            }
            .font(.system(size: 12))
            .frame(minWidth: 220, alignment: .trailing)
        }
        .padding(.leading, 64)
        .padding(.trailing, 90)
        .padding(.vertical, 6)
        .padding(.top, 5)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    /// Dock used to launch the different clue windows and the puzzle browser.
    private var dock: some View {
        HStack(spacing: 5) {
            AppIconView(
                name: "Music",
                icon: "music.note"
            ) {
                viewModel.openApp("music")
            }

            AppIconView(
                name: "Calendar",
                icon: "8.calendar"
            ) {
                viewModel.openApp("calendar")
            }

            AppIconView(
                name: "Reminder",
                icon: "list.bullet.rectangle.portrait"
            ) {
                viewModel.openApp("reminder")
            }

            AppIconView(
                name: "Photo",
                icon: "photo"
            ) {
                viewModel.openApp("fruit")
            }

            AppIconView(
                name: "Call",
                icon: "phone.circle.fill"
            ) {
                viewModel.openApp("calllog")
            }

            AppIconView(
                name: "Safari",
                icon: "safari.fill"
            ) {
                viewModel.openApp("safari")
            }
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 8)
        )
        .padding(.bottom, 18)
    }

    /// Maps the internal app identifier to the label shown in the menu bar.
    private var activeAppDisplayName: String {
        switch viewModel.activeApp {
        case "music": return "Music"
        case "calendar": return "Calendar"
        case "reminder": return "Reminder"
        case "fruit": return "Photo"
        case "calllog": return "Call"
        case "safari": return "Safari"
        case .none: return "Finder"
        case .some(let name):
            return name.capitalized
        }
    }
}
