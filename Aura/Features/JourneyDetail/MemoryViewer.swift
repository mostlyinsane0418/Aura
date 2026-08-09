import SwiftUI

/// Full-screen photo, edge to edge, black.
///
/// Swipe sideways through the journey; drag down to dismiss. The dismissal is
/// interactive and rubber-banded rather than a button, because letting go of a photo
/// should feel like putting it down.
struct MemoryViewer: View {
    let memoryIDs: [String]
    let initialMemoryID: String

    @Environment(\.dismiss) private var dismiss
    @State private var currentID: String
    @State private var dragOffset: CGSize = .zero

    init(memoryIDs: [String], initialMemoryID: String) {
        self.memoryIDs = memoryIDs
        self.initialMemoryID = initialMemoryID
        _currentID = State(initialValue: initialMemoryID)
    }

    /// Fades the backdrop out as the photo is pulled away, so the dismissal reads as
    /// one continuous gesture instead of a drag followed by a cut.
    private var dismissProgress: CGFloat {
        min(1, max(0, dragOffset.height / 260))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .opacity(1 - dismissProgress * 0.85)

            TabView(selection: $currentID) {
                ForEach(memoryIDs, id: \.self) { memoryID in
                    MemoryImage(memoryID: memoryID, targetSize: CGSize(width: 2200, height: 2200))
                        .aspectRatio(contentMode: .fit)
                        .tag(memoryID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .offset(dragOffset)
            .scaleEffect(1 - dismissProgress * 0.12)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(AuraTheme.Spacing.snug)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .tint(.white)
            .padding(AuraTheme.Spacing.regular)
            .opacity(1 - dismissProgress)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    guard value.translation.height > 0 else { return }
                    // Resist upward and sideways travel so the vertical intent stays
                    // unambiguous next to the paging gesture.
                    dragOffset = CGSize(
                        width: value.translation.width * 0.35,
                        height: value.translation.height
                    )
                }
                .onEnded { value in
                    if value.translation.height > 140 || value.predictedEndTranslation.height > 320 {
                        dismiss()
                    } else {
                        withAnimation(AuraTheme.Motion.standard) { dragOffset = .zero }
                    }
                }
        )
        .sensoryFeedback(Haptics.snap, trigger: currentID)
        .statusBarHidden()
    }
}
