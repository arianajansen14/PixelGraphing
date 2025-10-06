import SwiftUI
import SceneKit
import AppKit
internal import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedImage: NSImage?
    @State private var showAsGraph = false
    @State private var scnScene = SCNScene()
    @State private var planeNode: SCNNode?
    @State private var pixelNodes: [SCNNode] = []
    @State private var planePositions: [SCNVector3] = []
    @State private var graphPositions: [SCNVector3] = []

    var body: some View {
        VStack {
            Toggle("Organise into Graph", isOn: $showAsGraph)
                .padding()

            Button("Pick Image") {
                openImagePicker()
            }
            .padding()

            SceneView(scene: $scnScene)
                .frame(minWidth: 600, minHeight: 600)
        }
        .onChange(of: showAsGraph) { newValue in
            planeNode?.isHidden = newValue
            pixelNodes.forEach { $0.isHidden = !newValue }
            for (i, node) in pixelNodes.enumerated() {
                let moveAction = SCNAction.move(to: newValue ? graphPositions[i] : planePositions[i], duration: 1.0)
                moveAction.timingMode = .easeInEaseOut
                node.runAction(moveAction)
            }
        }
    }

    func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK,
           let url = panel.url,
           let image = NSImage(contentsOf: url) {
            selectedImage = image
            print("✅ Loaded image: \(url.lastPathComponent)")
            processImage(image)
        }
    }

    func processImage(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            print("❌ Failed to convert image to bitmap.")
            return
        }

        let width = Int(bitmap.pixelsWide)
        let height = Int(bitmap.pixelsHigh)
        let pixelStep = 8
        print("📸 Image Size: \(width)x\(height)")

        let parentNode = SCNNode()

        
        let plane = SCNPlane(width: CGFloat(width) * 0.01, height: CGFloat(height) * 0.01)
        plane.firstMaterial?.diffuse.contents = image
        let planeNode = SCNNode(geometry: plane)
        planeNode.eulerAngles = SCNVector3Zero
        parentNode.addChildNode(planeNode)

        
        var pixelNodes: [SCNNode] = []
        var planePositions: [SCNVector3] = []
        var graphPositions: [SCNVector3] = []
        for x in stride(from: 0, to: width, by: pixelStep) {
            for y in stride(from: 0, to: height, by: pixelStep) {
                guard let color = bitmap.colorAt(x: x, y: y) else { continue }

                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                color.usingColorSpace(.deviceRGB)?.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

                let xVal = Float(hue) * 10 - 5
                let yVal = Float(saturation) * 10 - 5
                let zVal = Float(brightness) * 10 - 5

                let planePosition = SCNVector3(
                    x: CGFloat(Float(x - width/2)) * 0.05,
                    y: CGFloat(Float(y - height/2)) * 0.05,
                    z: 0
                )
                let graphPosition = SCNVector3(x: CGFloat(xVal), y: CGFloat(yVal), z: CGFloat(zVal))

                planePositions.append(planePosition)
                graphPositions.append(graphPosition)

                let sphere = SCNSphere(radius: 0.05)
                sphere.firstMaterial?.diffuse.contents = NSColor(calibratedHue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
                let sphereNode = SCNNode(geometry: sphere)

                let randomStart = SCNVector3(
                    x: CGFloat(Float.random(in: -20...20)),
                    y: CGFloat(Float.random(in: -20...20)),
                    z: CGFloat(Float.random(in: -20...20))
                )
                sphereNode.position = randomStart

                let targetPosition = showAsGraph ? graphPosition : planePosition
                let moveAction = SCNAction.move(to: targetPosition, duration: 2.0)
                moveAction.timingMode = .easeOut
                sphereNode.runAction(moveAction)

                parentNode.addChildNode(sphereNode)
                pixelNodes.append(sphereNode)
            }
        }

        
        planeNode.isHidden = showAsGraph
        pixelNodes.forEach { $0.isHidden = !showAsGraph }

        for (i, node) in pixelNodes.enumerated() {
            let moveAction = SCNAction.move(to: showAsGraph ? graphPositions[i] : planePositions[i], duration: 1.0)
            moveAction.timingMode = .easeInEaseOut
            node.runAction(moveAction)
        }

        // Removed spinning animation

        let newScene = SCNScene()
        newScene.rootNode.addChildNode(parentNode)
        scnScene = newScene

        self.planeNode = planeNode
        self.pixelNodes = pixelNodes
        self.planePositions = planePositions
        self.graphPositions = graphPositions
    }
}

struct SceneView: NSViewRepresentable {
    @Binding var scene: SCNScene

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        return scnView
    }

    func updateNSView(_ scnView: SCNView, context: Context) {
        scnView.scene = scene
    }
}
