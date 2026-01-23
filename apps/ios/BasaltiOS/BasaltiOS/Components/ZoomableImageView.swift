import SwiftUI

struct ZoomableImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0
    @State private var showImage = false
    
    private let dismissThreshold: CGFloat = 0.7
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred background
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.2), value: backgroundOpacity)
                
                // Zoomable Image
                CachedAsyncImage(url: imageURL, targetSize: .zero) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                // Pinch to zoom
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(0.5, newScale) // Allow scaling down to 0.5 for dismiss effect
                                        
                                        // Fade background as we zoom out
                                        if newScale < 1.0 {
                                            backgroundOpacity = Double(max(0.3, newScale))
                                        } else {
                                            backgroundOpacity = 1.0
                                        }
                                    }
                                    .onEnded { value in
                                        let finalScale = lastScale * value
                                        
                                        // Dismiss if zoomed out enough
                                        if finalScale < dismissThreshold {
                                            withAnimation(.easeOut(duration: 0.25)) {
                                                scale = 0.3
                                                backgroundOpacity = 0
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                isPresented = false
                                            }
                                        } else if finalScale < 1.0 {
                                            // Snap back to 1.0
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                scale = 1.0
                                                backgroundOpacity = 1.0
                                            }
                                            lastScale = 1.0
                                        } else {
                                            // Keep the scale, max at 5x
                                            lastScale = min(finalScale, 5.0)
                                            scale = lastScale
                                        }
                                    }
                            )
                            .simultaneousGesture(
                                // Drag gesture (only when zoomed in)
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        } else {
                                            // When at 1x or less, drag moves image and affects opacity
                                            offset = value.translation
                                            let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                            backgroundOpacity = Double(max(0.3, 1 - dragDistance / 400))
                                        }
                                    }
                                    .onEnded { value in
                                        if scale > 1.0 {
                                            lastOffset = offset
                                        } else {
                                            // Check if dragged far enough to dismiss
                                            let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                            if dragDistance > 150 {
                                                // Dismiss
                                                withAnimation(.easeOut(duration: 0.25)) {
                                                    scale = 0.5
                                                    backgroundOpacity = 0
                                                    offset = CGSize(
                                                        width: value.translation.width * 2,
                                                        height: value.translation.height * 2
                                                    )
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    isPresented = false
                                                }
                                            } else {
                                                // Snap back
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                    offset = .zero
                                                    backgroundOpacity = 1.0
                                                }
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                // Double tap to toggle zoom
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                        lastScale = 2.5
                                    }
                                }
                            }
                    case .failure:
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Close Button (visible when not dragging)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                backgroundOpacity = 0
                                scale = 0.8
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.8))
                                .padding()
                        }
                    }
                    Spacer()
                }
                .opacity(backgroundOpacity)
            }
        }
        .onAppear {
            // Animate in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showImage = true
            }
        }
    }
}

#Preview {
    ZoomableImageView(
        imageURL: URL(string: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4")!,
        isPresented: .constant(true)
    )
}
