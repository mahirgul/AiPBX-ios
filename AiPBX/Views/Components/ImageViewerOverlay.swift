import SwiftUI
import UIKit

/// Native full-screen image viewer with pinch-to-zoom, pan, double-tap,
/// and share/save sheet capabilities. Replaces external Safari opening.
public struct ImageViewerOverlay: View {
    public let imageUrl: URL
    public let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showShareSheet: Bool = false
    @State private var downloadedImage: UIImage? = nil

    public init(imageUrl: URL, onDismiss: @escaping () -> Void) {
        self.imageUrl = imageUrl
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    if scale <= 1.0 {
                        onDismiss()
                    }
                }

            // Image display
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { val in
                                    let delta = val / lastScale
                                    lastScale = val
                                    let newScale = scale * delta
                                    scale = min(max(newScale, 1.0), 5.0)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                                .simultaneously(
                                    with: DragGesture()
                                        .onChanged { val in
                                            if scale > 1.0 {
                                                offset = CGSize(
                                                    width: lastOffset.width + val.translation.width,
                                                    height: lastOffset.height + val.translation.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            lastOffset = offset
                                        }
                                )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                        .onAppear {
                            downloadImageForSharing()
                        }
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.7))
                        Text(L("Could not load the photo"))
                            .foregroundColor(.white.opacity(0.8))
                    }
                case .empty:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                @unknown default:
                    EmptyView()
                }
            }

            // Top Bar Overlay
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                            .padding()
                    }

                    Spacer()

                    if let image = downloadedImage {
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.85))
                                .padding()
                        }
                        .sheet(isPresented: $showShareSheet) {
                            ActivityViewController(activityItems: [image])
                        }
                    }
                }
                Spacer()
            }
        }
        .transition(.opacity)
    }

    private func downloadImageForSharing() {
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: imageUrl),
               let uiImg = UIImage(data: data) {
                await MainActor.run {
                    self.downloadedImage = uiImg
                }
            }
        }
    }
}

/// Helper wrapper for UIActivityViewController in SwiftUI.
private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
