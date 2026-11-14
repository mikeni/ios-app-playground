import SwiftUI
import simd

/// A camera that orbits around a target point. `ContentView` drives it
/// from gestures, applies it to the RealityKit camera entity, and uses
/// the same numbers to work out where 3D points land on screen.
struct OrbitCamera: Equatable {
    /// Rotation around the vertical axis, in radians. 0 looks down -Z.
    var yaw: Float = 0
    /// Elevation above the target's horizontal plane, in radians.
    var pitch: Float = 0.18
    /// Distance from the target, in meters.
    var distance: Float = 2.0
    var target: SIMD3<Float>
    var fieldOfViewDegrees: Float = 50

    static let pitchRange: ClosedRange<Float> = -0.05...1.2
    static let distanceRange: ClosedRange<Float> = 1.0...4.5

    var position: SIMD3<Float> {
        let direction = SIMD3<Float>(
            sin(yaw) * cos(pitch),
            sin(pitch),
            cos(yaw) * cos(pitch)
        )
        return target + direction * distance
    }

    /// Projects a world-space point into a view whose size is `viewSize`.
    /// Returns points with the origin at the top-left, or `nil` if the
    /// point is behind the camera.
    ///
    /// This mirrors what RealityKit does with a `PerspectiveCamera` that
    /// uses a vertical field of view, so the result lines up with the
    /// rendered scene.
    func project(_ point: SIMD3<Float>, in viewSize: CGSize) -> CGPoint? {
        let eye = position
        let forward = simd_normalize(target - eye)
        let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0)))
        let up = simd_cross(right, forward)

        let relative = point - eye
        let x = simd_dot(relative, right)
        let y = simd_dot(relative, up)
        let depth = simd_dot(relative, forward)
        guard depth > 0.001 else { return nil }

        let aspect = Float(viewSize.width / viewSize.height)
        let tanHalfFov = tan(fieldOfViewDegrees * .pi / 360)
        let ndcX = (x / depth) / (tanHalfFov * aspect)
        let ndcY = (y / depth) / tanHalfFov

        return CGPoint(
            x: CGFloat((ndcX + 1) / 2) * viewSize.width,
            y: CGFloat((1 - ndcY) / 2) * viewSize.height
        )
    }
}

/// Solves for the 2D projective transform that maps one quadrilateral
/// onto another. Used to warp the flat SwiftUI form onto the board's
/// on-screen outline.
enum Homography {
    /// - Parameters:
    ///   - source: Four corners in the view's own coordinates.
    ///   - destination: Where those corners should end up, same order.
    static func transform(from source: [CGPoint], to destination: [CGPoint]) -> ProjectionTransform? {
        guard source.count == 4, destination.count == 4 else { return nil }

        // Unknowns a...h, with the mapping
        //   x' = (a·x + b·y + c) / (g·x + h·y + 1)
        //   y' = (d·x + e·y + f) / (g·x + h·y + 1)
        // Each point pair contributes two linear equations.
        var rows: [[Double]] = []
        for index in 0..<4 {
            let x = Double(source[index].x), y = Double(source[index].y)
            let u = Double(destination[index].x), v = Double(destination[index].y)
            rows.append([x, y, 1, 0, 0, 0, -u * x, -u * y, u])
            rows.append([0, 0, 0, x, y, 1, -v * x, -v * y, v])
        }
        guard let solution = solve(rows) else { return nil }

        // ProjectionTransform multiplies row vectors: [x y 1] * M, so the
        // coefficients for x go down the first column, for y down the second.
        var transform = ProjectionTransform()
        transform.m11 = CGFloat(solution[0]); transform.m21 = CGFloat(solution[1]); transform.m31 = CGFloat(solution[2])
        transform.m12 = CGFloat(solution[3]); transform.m22 = CGFloat(solution[4]); transform.m32 = CGFloat(solution[5])
        transform.m13 = CGFloat(solution[6]); transform.m23 = CGFloat(solution[7]); transform.m33 = 1
        return transform
    }

    /// Gauss-Jordan elimination with partial pivoting on an 8x9 augmented matrix.
    private static func solve(_ input: [[Double]]) -> [Double]? {
        var matrix = input
        let count = 8
        for column in 0..<count {
            var pivot = column
            for row in (column + 1)..<count where abs(matrix[row][column]) > abs(matrix[pivot][column]) {
                pivot = row
            }
            guard abs(matrix[pivot][column]) > 1e-12 else { return nil }
            matrix.swapAt(column, pivot)

            let divisor = matrix[column][column]
            for c in column...count { matrix[column][c] /= divisor }

            for row in 0..<count where row != column {
                let factor = matrix[row][column]
                guard factor != 0 else { continue }
                for c in column...count { matrix[row][c] -= factor * matrix[column][c] }
            }
        }
        return (0..<count).map { matrix[$0][count] }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
