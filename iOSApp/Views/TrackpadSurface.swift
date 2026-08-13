import SwiftUI
import UIKit

/// Adaptateur SwiftUI de la surface multi-touch.
struct TrackpadSurface: UIViewRepresentable {
    var pointerSensitivity: Double
    var scrollSensitivity: Double
    var pointerAcceleration: Bool
    var momentum: Bool
    var haptics: Bool
    var naturalScrolling: Bool
    var threeFingerGestures: Bool
    var send: (Message) -> Void

    func makeUIView(context: Context) -> TrackpadSurfaceView {
        let view = TrackpadSurfaceView()
        bind(view)
        return view
    }

    func updateUIView(_ uiView: TrackpadSurfaceView, context: Context) {
        bind(uiView)
    }

    private func bind(_ view: TrackpadSurfaceView) {
        view.pointerAccelerationEnabled = pointerAcceleration
        view.momentumEnabled = momentum
        view.hapticsEnabled = haptics
        view.naturalScrolling = naturalScrolling
        view.threeFingerGestures = threeFingerGestures

        let pointer = pointerSensitivity
        let scroll = scrollSensitivity

        view.onMove = { dx, dy in
            send(.trackpad(dx: Double(dx) * pointer, dy: Double(dy) * pointer))
        }
        view.onScroll = { dx, dy, phase in
            send(.scroll(dx: Double(dx) * scroll, dy: Double(dy) * scroll, phase: phase))
        }
        view.onZoom = { magnification, phase in
            send(.zoom(magnification: Double(magnification), phase: phase))
        }
        view.onClick = { button, down in
            send(.click(button: button, down: down))
        }
        view.onGesture = { action in
            send(.gesture(action))
        }
    }
}
