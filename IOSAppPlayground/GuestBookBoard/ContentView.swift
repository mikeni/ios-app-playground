import SwiftUI
import RealityKit
import Playgrounds

/// A small 3D world with a standing board that carries a form.
///
/// On iOS and macOS, RealityKit can't host SwiftUI views inside the
/// scene, so the form is a real SwiftUI view layered over the
/// `RealityView` and warped onto the board's on-screen outline with a
/// projective transform. Because the camera is driven from SwiftUI
/// state, the overlay and the 3D render stay in sync as you orbit.
struct ContentView: View {
    @State private var guestBook = GuestBook()
    @State private var camera = OrbitCamera(target: WorldScene.boardCenter)
    @State private var cameraEntity = PerspectiveCamera()

    @State private var dragStart: (yaw: Float, pitch: Float)?
    @State private var zoomStartDistance: Float?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RealityView { content in
                    #if !os(visionOS)
                    // Render a fully virtual scene instead of an AR camera feed.
                    content.camera = .virtual
                    cameraEntity.camera.fieldOfViewInDegrees = camera.fieldOfViewDegrees
                    cameraEntity.look(at: camera.target, from: camera.position, relativeTo: nil)
                    content.add(cameraEntity)
                    #endif

                    content.add(WorldScene.makeWorld(guestBook: guestBook))
                } update: { _ in
                    #if !os(visionOS)
                    cameraEntity.look(at: camera.target, from: camera.position, relativeTo: nil)
                    #endif
                }
                .gesture(orbitGesture)
                .simultaneousGesture(zoomGesture)

                #if !os(visionOS)
                boardForm(in: geometry.size)
                #endif
            }
        }
        .background(skyGradient)
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            GuestBookOverlay(guestBook: guestBook)
                .padding()
        }
    }

    // MARK: - Form on the board

    /// Warps the flat form onto the board by mapping its corners onto the
    /// projected corners of the board's form area. Hidden when the camera
    /// is behind the board.
    @ViewBuilder
    private func boardForm(in viewSize: CGSize) -> some View {
        let isFacingBoard = camera.position.z > WorldScene.boardCenter.z
        let corners = WorldScene.formCorners.compactMap { camera.project($0, in: viewSize) }
        let formSize = BoardFormView.size
        let flatCorners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: formSize.width, y: 0),
            CGPoint(x: formSize.width, y: formSize.height),
            CGPoint(x: 0, y: formSize.height),
        ]

        if isFacingBoard, corners.count == 4,
           let transform = Homography.transform(from: flatCorners, to: corners) {
            #if canImport(UIKit)
            // Warp at the Core Animation level so UIKit-backed text fields
            // stay on the same plane as the rest of the form.
            ProjectedBoardForm(guestBook: guestBook, transform: transform)
                .frame(width: viewSize.width, height: viewSize.height)
            #else
            BoardFormView(guestBook: guestBook)
                .projectionEffect(transform)
            #endif
        }
    }

    // MARK: - Camera gestures

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = (camera.yaw, camera.pitch)
                }
                guard let start = dragStart else { return }
                let sensitivity: Float = 0.006
                camera.yaw = start.yaw - Float(value.translation.width) * sensitivity
                camera.pitch = (start.pitch + Float(value.translation.height) * sensitivity)
                    .clamped(to: OrbitCamera.pitchRange)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomStartDistance == nil {
                    zoomStartDistance = camera.distance
                }
                guard let start = zoomStartDistance else { return }
                camera.distance = (start / Float(value.magnification))
                    .clamped(to: OrbitCamera.distanceRange)
            }
            .onEnded { _ in zoomStartDistance = nil }
    }

    private var skyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.55, green: 0.75, blue: 0.95),
                Color(red: 0.85, green: 0.92, blue: 0.98),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Lists the most recent submissions so the data entered on the
/// 3D board is visible outside the scene.
private struct GuestBookOverlay: View {
    let guestBook: GuestBook

    var body: some View {
        if guestBook.entries.isEmpty {
            Text("Drag to orbit, pinch to zoom. Fill in the form on the board.")
                .font(.footnote)
                .padding(10)
                .background(.thinMaterial, in: Capsule())
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Guest book")
                    .font(.headline)
                ForEach(guestBook.entries.prefix(3)) { entry in
                    HStack(spacing: 8) {
                        Image(systemName: entry.mood.symbolName)
                        Text(entry.name).bold()
                        if !entry.email.isEmpty {
                            Text(entry.email).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.date, style: .time)
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
            .padding(12)
            .frame(maxWidth: 420, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    ContentView()
}

#Playground {
    _ = 1 + 2
}
