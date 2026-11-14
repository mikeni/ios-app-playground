import SwiftUI
import RealityKit

/// Builds the RealityKit entities for the 3D world: a ground plane and a
/// standing sign board on two posts. On visionOS the SwiftUI form is
/// attached directly to the board; on iOS and macOS `ContentView` draws
/// the form as an overlay warped onto `formCorners`.
///
/// All sizes are in meters. The board faces +Z, toward the default camera.
enum WorldScene {
    static let boardWidth: Float = 0.9
    static let boardHeight: Float = 0.75
    static let boardThickness: Float = 0.04
    static let postHeight: Float = 0.7
    static let boardCenter: SIMD3<Float> = [0, postHeight + boardHeight / 2, 0]

    /// Z of the panel's front face, where the form sits.
    static let boardFaceZ: Float = boardThickness * 0.3 + boardThickness * 0.25

    /// The form's footprint on the board, in meters. Its aspect ratio
    /// matches `BoardFormView.size` so the warped form isn't stretched.
    static let formWidth: Float = boardWidth - 0.08
    static let formHeight: Float = formWidth * Float(BoardFormView.size.height / BoardFormView.size.width)

    /// World-space corners of the form: top-left, top-right, bottom-right, bottom-left.
    static var formCorners: [SIMD3<Float>] {
        let halfWidth = formWidth / 2
        let halfHeight = formHeight / 2
        let z = boardFaceZ + 0.002
        return [
            boardCenter + [-halfWidth, halfHeight, z],
            boardCenter + [halfWidth, halfHeight, z],
            boardCenter + [halfWidth, -halfHeight, z],
            boardCenter + [-halfWidth, -halfHeight, z],
        ]
    }

    @MainActor
    static func makeWorld(guestBook: GuestBook) -> Entity {
        let root = Entity()
        root.name = "world"

        root.addChild(makeGround())
        root.addChild(makeSignBoard())
        root.addChild(makeSunlight())

        #if os(visionOS)
        root.addChild(makeFormAttachment(guestBook: guestBook))
        #endif

        return root
    }

    // MARK: - Pieces

    private static func makeGround() -> ModelEntity {
        let grass = SimpleMaterial(
            color: SimpleMaterial.Color(red: 0.36, green: 0.62, blue: 0.36, alpha: 1),
            roughness: 1,
            isMetallic: false
        )
        let ground = ModelEntity(
            mesh: .generatePlane(width: 8, depth: 8),
            materials: [grass]
        )
        ground.name = "ground"
        return ground
    }

    private static func makeSignBoard() -> Entity {
        let sign = Entity()
        sign.name = "sign"

        let wood = SimpleMaterial(
            color: SimpleMaterial.Color(red: 0.45, green: 0.30, blue: 0.18, alpha: 1),
            roughness: 0.8,
            isMetallic: false
        )
        let panel = SimpleMaterial(
            color: SimpleMaterial.Color(red: 0.93, green: 0.90, blue: 0.84, alpha: 1),
            roughness: 0.6,
            isMetallic: false
        )

        // Two posts holding the board up.
        let postSize: Float = 0.06
        for xOffset in [-boardWidth * 0.4, boardWidth * 0.4] {
            let post = ModelEntity(
                mesh: .generateBox(width: postSize, height: postHeight, depth: postSize),
                materials: [wood]
            )
            post.position = [xOffset, postHeight / 2, 0]
            sign.addChild(post)
        }

        // Wooden frame, slightly larger than the panel.
        let frame = ModelEntity(
            mesh: .generateBox(
                width: boardWidth + 0.08,
                height: boardHeight + 0.08,
                depth: boardThickness,
                cornerRadius: 0.01
            ),
            materials: [wood]
        )
        frame.position = boardCenter
        sign.addChild(frame)

        // The light panel the form sits on, pushed slightly forward.
        let board = ModelEntity(
            mesh: .generateBox(
                width: boardWidth,
                height: boardHeight,
                depth: boardThickness * 0.5
            ),
            materials: [panel]
        )
        board.position = boardCenter + [0, 0, boardThickness * 0.3]
        sign.addChild(board)

        return sign
    }

    private static func makeSunlight() -> Entity {
        let sun = DirectionalLight()
        sun.light.intensity = 3000
        sun.light.color = .white
        sun.look(at: boardCenter, from: [1.5, 3, 2.5], relativeTo: nil)
        return sun
    }

    #if os(visionOS)
    /// On visionOS RealityKit can host SwiftUI directly on an entity.
    @MainActor
    private static func makeFormAttachment(guestBook: GuestBook) -> Entity {
        let attachment = Entity()
        attachment.name = "form"
        attachment.components.set(
            ViewAttachmentComponent(rootView: BoardFormView(guestBook: guestBook))
        )
        // Attachments render at about 1360 points per meter.
        let naturalWidth = Float(BoardFormView.size.width) / 1360
        attachment.scale = .init(repeating: formWidth / naturalWidth)
        attachment.position = boardCenter + [0, 0, boardFaceZ + 0.005]
        return attachment
    }
    #endif
}
