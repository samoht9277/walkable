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
        return view
    }

    func updateUIView(_ uiView: DrawingCanvasUIView, context: Context) {
        uiView.isUserInteractionEnabled = isDrawing
    }
}

@MainActor
class DrawingCanvasUIView: UIView {
    var onDrawingComplete: (([CGPoint]) -> Void)?
    private var points: [CGPoint] = []
    private var currentPath = UIBezierPath()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        points.removeAll()
        currentPath = UIBezierPath()
        let point = touch.location(in: self)
        points.append(point)
        currentPath.move(to: point)
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        points.append(point)
        currentPath.addLine(to: point)
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Close the loop by connecting back to start
        if let first = points.first {
            points.append(first)
            currentPath.addLine(to: first)
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
        currentPath = UIBezierPath()
        setNeedsDisplay()
    }
}
