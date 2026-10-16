import Combine
import Foundation

@MainActor
final class PanelPresentationState: ObservableObject {
    @Published var isPresented: Bool
    @Published var anchorX: CGFloat
    private(set) var generation: UInt64 = 0

    init(isPresented: Bool = true, anchorX: CGFloat = 0.5) {
        self.isPresented = isPresented
        self.anchorX = anchorX
    }

    @discardableResult
    func beginTransition(isPresented: Bool) -> UInt64 {
        generation &+= 1
        self.isPresented = isPresented
        return generation
    }

    func isCurrent(_ generation: UInt64, isPresented: Bool) -> Bool {
        self.generation == generation && self.isPresented == isPresented
    }
}

/// Interpolates the window's actual origin and opacity, without resizing it.
struct PanelWindowMotion {
    struct Sample: Equatable {
        let origin: CGPoint
        let opacity: CGFloat
    }

    let from: Sample
    let to: Sample
    let startedAt: TimeInterval
    let duration: TimeInterval

    static func visibility(
        _ isPresented: Bool, from: Sample, restingOrigin: CGPoint,
        reduceMotion: Bool, startedAt: TimeInterval
    ) -> PanelWindowMotion {
        let origin = reduceMotion ? from.origin
            : CGPoint(x: restingOrigin.x, y: restingOrigin.y + (isPresented ? 0 : 6))
        return PanelWindowMotion(from: from, to: Sample(origin: origin, opacity: isPresented ? 1 : 0),
                                 startedAt: startedAt, duration: reduceMotion ? 0.08 : isPresented ? 0.22 : 0.14)
    }

    func sample(at time: TimeInterval) -> Sample {
        let fraction = min(1, max(0, (time - startedAt) / duration))
        // Smooth deceleration, with no overshoot beyond the menu bar anchor.
        let eased = CGFloat(1 - pow(1 - fraction, 3))
        return Sample(
            origin: CGPoint(x: from.origin.x + (to.origin.x - from.origin.x) * eased,
                            y: from.origin.y + (to.origin.y - from.origin.y) * eased),
            opacity: from.opacity + (to.opacity - from.opacity) * eased
        )
    }

    func isComplete(at time: TimeInterval) -> Bool {
        time - startedAt >= duration
    }
}
