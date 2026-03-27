import SwiftUI
import MapKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var isDrawing: Bool
    var onDrawingComplete: ([CGPoint]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingComplete: onDrawingComplete)
    }

    func makeUIView(context: Context) -> DrawingCanvasUIView {
        let view = DrawingCanvasUIView()
        view.backgroundColor = .clear

        let pan = DrawingGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        context.coordinator.canvasView = view

        return view
    }

    func updateUIView(_ uiView: DrawingCanvasUIView, context: Context) {
        uiView.gestureRecognizers?.forEach { $0.isEnabled = isDrawing }
        context.coordinator.onDrawingComplete = onDrawingComplete
    }

    @MainActor
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDrawingComplete: ([CGPoint]) -> Void
        weak var canvasView: DrawingCanvasUIView?

        init(onDrawingComplete: @escaping ([CGPoint]) -> Void) {
            self.onDrawingComplete = onDrawingComplete
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = canvasView else { return }
            let local = gesture.location(in: view)
            let global = gesture.location(in: nil)

            switch gesture.state {
            case .began:
                view.beginPath(local: local, global: global)
            case .changed:
                view.addPoint(local: local, global: global)
            case .ended, .cancelled:
                view.finishPath()
                onDrawingComplete(view.globalPoints)
            default:
                break
            }
        }

        // Allow the map's gestures to work simultaneously for 2+ finger gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// Custom gesture recognizer that fails immediately on multitouch
class DrawingGestureRecognizer: UIPanGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (event.allTouches?.count ?? 0) > 1 {
            state = .failed
            return
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if (event.allTouches?.count ?? 0) > 1 {
            state = .failed
            return
        }
        super.touchesMoved(touches, with: event)
    }
}

@MainActor
class DrawingCanvasUIView: UIView {
    private(set) var globalPoints: [CGPoint] = []
    private var localPoints: [CGPoint] = []
    private var currentPath = UIBezierPath()

    func beginPath(local: CGPoint, global: CGPoint) {
        globalPoints.removeAll()
        localPoints.removeAll()
        currentPath = UIBezierPath()
        localPoints.append(local)
        globalPoints.append(global)
        currentPath.move(to: local)
        setNeedsDisplay()
    }

    func addPoint(local: CGPoint, global: CGPoint) {
        localPoints.append(local)
        globalPoints.append(global)
        currentPath.addLine(to: local)
        setNeedsDisplay()
    }

    func finishPath() {
        if let firstLocal = localPoints.first, let firstGlobal = globalPoints.first {
            localPoints.append(firstLocal)
            globalPoints.append(firstGlobal)
            currentPath.addLine(to: firstLocal)
            currentPath.close()
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.withAlphaComponent(0.6).setStroke()
        currentPath.lineWidth = 4
        currentPath.lineCapStyle = .round
        currentPath.lineJoinStyle = .round
        currentPath.stroke()
    }

    func clear() {
        globalPoints.removeAll()
        localPoints.removeAll()
        currentPath = UIBezierPath()
        setNeedsDisplay()
    }
}
