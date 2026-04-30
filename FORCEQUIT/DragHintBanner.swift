import SwiftUI

/// Lightweight helper banner that teaches the draggable window mechanic.
struct DragHintBanner: View {
    /// Called when the player dismisses the hint banner.
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)

            Text("Every app window can be dragged around.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .frame(maxWidth: 280, alignment: .trailing)
        .padding(.trailing, 16)
        .padding(.top, 16)
    }
}
