#if canImport(UIKit) && !os(visionOS)
import SwiftUI
import UIKit

/// Hosts `BoardFormView` in UIKit and warps it with a Core Animation
/// transform instead of SwiftUI's `projectionEffect`.
///
/// On iOS, `TextField` is backed by `UITextField`. SwiftUI only applies an
/// affine approximation of a projective transform to such platform views,
/// so under `projectionEffect` the fields slide off the card at steeper
/// camera angles. Applying the same homography as a `CATransform3D` on the
/// hosting view's layer warps every control on one plane.
struct ProjectedBoardForm: UIViewRepresentable {
    let guestBook: GuestBook
    let transform: ProjectionTransform

    func makeUIView(context: Context) -> ProjectedFormContainerView {
        let host = UIHostingController(rootView: BoardFormView(guestBook: guestBook))
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        context.coordinator.host = host
        return ProjectedFormContainerView(hosted: host.view, size: BoardFormView.size)
    }

    func updateUIView(_ view: ProjectedFormContainerView, context: Context) {
        view.projection = transform
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Keeps the hosting controller alive for the lifetime of the view.
    final class Coordinator {
        var host: UIHostingController<BoardFormView>?
    }
}

/// A transparent, full-size view that owns the hosted form, applies the
/// projection to its layer, and maps touches back through the inverse
/// transform so the warped controls stay tappable. Points outside the
/// form return `nil` from hit testing so orbit gestures reach the scene.
final class ProjectedFormContainerView: UIView {
    private let hosted: UIView

    var projection = ProjectionTransform() {
        didSet { applyProjection() }
    }

    init(hosted: UIView, size: CGSize) {
        self.hosted = hosted
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false

        // Transform about the top-left corner, matching the homography's
        // source rectangle whose origin is (0, 0).
        hosted.autoresizingMask = []
        hosted.layer.anchorPoint = .zero
        hosted.bounds = CGRect(origin: .zero, size: size)
        hosted.layer.position = .zero
        addSubview(hosted)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func applyProjection() {
        // Both ProjectionTransform and CATransform3D use the row-vector
        // convention, so the 3x3 maps into the x, y, w rows and columns.
        var t = CATransform3DIdentity
        t.m11 = projection.m11; t.m12 = projection.m12; t.m14 = projection.m13
        t.m21 = projection.m21; t.m22 = projection.m22; t.m24 = projection.m23
        t.m41 = projection.m31; t.m42 = projection.m32; t.m44 = projection.m33
        hosted.layer.transform = t

        // UIKit doesn't recompute accessibility frames for a transformed
        // layer on its own, so tell assistive tech the layout moved.
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let local = unproject(point), hosted.bounds.contains(local) else {
            return nil
        }
        return hosted.hitTest(local, with: event)
    }

    /// Maps a point in this view's coordinates back onto the flat form.
    private func unproject(_ point: CGPoint) -> CGPoint? {
        let inverse = projection.inverted()
        let w = inverse.m13 * point.x + inverse.m23 * point.y + inverse.m33
        guard abs(w) > 1e-9 else { return nil }
        return CGPoint(
            x: (inverse.m11 * point.x + inverse.m21 * point.y + inverse.m31) / w,
            y: (inverse.m12 * point.x + inverse.m22 * point.y + inverse.m32) / w
        )
    }
}
#endif
