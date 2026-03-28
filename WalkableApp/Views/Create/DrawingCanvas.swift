import SwiftUI

struct DrawingCanvas: View {
    @Binding var isDrawing: Bool
    var onDrawingComplete: ([CGPoint]) -> Void

    @State private var localPoints: [CGPoint] = []
    @State private var globalPoints: [CGPoint] = []
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard localPoints.count >= 2 else { return }
                var path = Path()
                path.move(to: localPoints[0])
                for point in localPoints.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(.blue.opacity(0.6)), lineWidth: 4)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.15)
                    .sequenced(before: DragGesture(minimumDistance: 1, coordinateSpace: .local))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            guard let drag else { return }
                            let local = drag.location
                            let frame = geo.frame(in: .global)
                            let global = CGPoint(x: local.x + frame.origin.x, y: local.y + frame.origin.y)

                            if localPoints.isEmpty {
                                localPoints = [local]
                                globalPoints = [global]
                            } else {
                                localPoints.append(local)
                                globalPoints.append(global)
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { value in
                        switch value {
                        case .second(true, _):
                            if let firstLocal = localPoints.first, let firstGlobal = globalPoints.first {
                                localPoints.append(firstLocal)
                                globalPoints.append(firstGlobal)
                            }
                            onDrawingComplete(globalPoints)
                        default:
                            break
                        }
                    }
            )
        }
    }

    func clear() {
        localPoints.removeAll()
        globalPoints.removeAll()
    }
}
