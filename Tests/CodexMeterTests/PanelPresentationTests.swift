import Foundation
import Testing
@testable import CodexMeter

struct PanelPresentationTests {
    @Test @MainActor
    func reopeningDuringClosePreservesTheCurrentFrameAndRejectsOldCompletion() {
        let state = PanelPresentationState(isPresented: false)
        let open = state.beginTransition(isPresented: true)
        let origin = CGPoint(x: 100, y: 100)
        let opening = PanelWindowMotion.visibility(
            true,
            from: .init(origin: CGPoint(x: 100, y: 106), opacity: 0),
            restingOrigin: origin, reduceMotion: false, startedAt: 0
        )
        #expect(opening.duration == 0.22)
        let visible = opening.sample(at: 0.08)
        let close = state.beginTransition(isPresented: false)
        let closing = PanelWindowMotion.visibility(false, from: visible, restingOrigin: origin,
                                                   reduceMotion: false, startedAt: 0.08)
        #expect(closing.duration == 0.14)
        #expect(closing.to == opening.from)
        #expect(closing.sample(at: 0.08) == visible)
        #expect(!state.isCurrent(open, isPresented: true))
        let interrupted = closing.sample(at: 0.12)
        let reopen = state.beginTransition(isPresented: true)
        let reopening = PanelWindowMotion.visibility(true, from: interrupted, restingOrigin: origin,
                                                     reduceMotion: false, startedAt: 0.12)
        #expect(reopening.sample(at: 0.12) == interrupted)
        #expect(!state.isCurrent(close, isPresented: false))
        #expect(state.isCurrent(reopen, isPresented: true))
        #expect(reopening.sample(at: 1) == opening.to)
        #expect(reopening.isComplete(at: 1))
    }

    @Test
    func reducedMotionOnlyFadesAndFinishesWithinOneTenthOfASecond() {
        let origin = CGPoint(x: 100, y: 200)
        for visible in [true, false] {
            let motion = PanelWindowMotion.visibility(visible, from: .init(origin: origin, opacity: visible ? 0 : 1),
                                                       restingOrigin: CGPoint(x: 100, y: 194),
                                                       reduceMotion: true, startedAt: 0)
            #expect(motion.duration <= 0.1)
            #expect(motion.sample(at: 0.04).origin == origin)
            #expect((0...1).contains(motion.sample(at: 0.04).opacity))
            #expect(motion.sample(at: 0.1).opacity == (visible ? 1 : 0))
            #expect(motion.isComplete(at: 0.1))
        }
    }
}
