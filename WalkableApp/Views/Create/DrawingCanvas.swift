import SwiftUI
import MapKit

struct DrawingCanvas: UIViewRepresentable {
    @Binding var isDrawing: Bool
    var onDrawingComplete: ([CGPoint]) -> Void

    func makeUIView(context: Context) -> DrawingCanvasUIView {
        let view = DrawingCanvasUIView()
        view.onDrawingComplete = onDrawingComplete
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasUIView, context: Context) {
        uiView.isUserInteractionEnabled = isDrawing
    }
}

@MainActor
class DrawingCanvasUIView: UIView {
    var onDrawingComplete: (([CGPoint]) -> Void)?
    private var points: [CGPoint] = []       // window/global coordinates for map conversion
    private var localPoints: [CGPoint] = []  // local coordinates for drawing the path
    private var currentPath = UIBezierPath()

    private var isMultitouch = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Two+ fingers = map gesture, not drawing
        let allTouches = event?.allTouches ?? touches
        if allTouches.count > 1 { isMultitouch = true; return }
        isMultitouch = false

        guard let touch = touches.first else { return }
        points.removeAll()
        localPoints.removeAll()
        currentPath = UIBezierPath()
        let local = touch.location(in: self)
        let global = touch.location(in: nil)
        localPoints.append(local)
        points.append(global)
        currentPath.move(to: local)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        if allTouches.count > 1 { isMultitouch = true; return }
        if isMultitouch { return }
        guard let touch = touches.first else { return }
        let local = touch.location(in: self)
        let global = touch.location(in: nil)
        localPoints.append(local)
        points.append(global)
        currentPath.addLine(to: local)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isMultitouch { isMultitouch = false; return }
        if let firstLocal = localPoints.first, let firstGlobal = points.first {
            localPoints.append(firstLocal)
            points.append(firstGlobal)
            currentPath.addLine(to: firstLocal)
            currentPath.close()
        }
        setNeedsDisplay()
        onDrawingComplete?(points)
    }

    override func draw(_ rect: CGRect) {
        UIColor.systemBlue.withAlphaComponent(0.6).setStroke()
        currentPath.lineWidth = 4
        currentPath.lineCapStyle = .round
        currentPath.lineJoinStyle = .round
        currentPath.stroke()
    }

    func clear() {
        points.removeAll()
        localPoints.removeAll()
        currentPath = UIBezierPath()
        setNeedsDisplay()
    }
}
