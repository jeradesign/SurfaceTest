//
//  ImmersiveView.swift
//  SurfaceTest
//
//  Created by John Brewer on 11/14/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    @State var planeAnchors: [UUID: PlaneAnchor] = [:]
    @State var entityMap: [UUID: Entity] = [:]
    @State var rootEntity: Entity!
    let session = ARKitSession()
    let planeData = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
    let ceilingMaterial = UnlitMaterial(color: .red)
    let floorMaterial = UnlitMaterial(color: .yellow)
    let tableMaterial = UnlitMaterial(color: .blue)
    let wallMaterial = UnlitMaterial(color: .green)
    let defaultMaterial = UnlitMaterial(color: .gray)

    var body: some View {
        RealityView (make: { content in
            // Add the initial RealityKit content
            rootEntity = Entity()
            content.add(rootEntity)
        })
        .task {
            Task {
                try await session.run([planeData])

                for await update in planeData.anchorUpdates {
                    switch update.event {
                    case .added, .updated:
                        await updatePlane(update.anchor)
                    case .removed:
                        removePlane(update.anchor)
                    }

                }
            }
        }
    }

    @MainActor
    func updatePlane(_ anchor: PlaneAnchor) async {
        // Add a new entity to represent this plane.
        var material: UnlitMaterial?
        switch anchor.surfaceClassification {
        case .ceiling:
            material = ceilingMaterial
        case .floor:
            material = floorMaterial
        case .table:
            material = tableMaterial
        case .wall:
            material = wallMaterial
        default:
            material = defaultMaterial
        }

        guard let material else {
            return
        }

        guard let mesh = try? await MeshResource(from: anchor) else {
            fatalError("Couldn't create MeshResource for anchor \(anchor.description)")
        }

        let entity = ModelEntity(mesh: mesh, materials: [material])

        if let oldEntity = entityMap[anchor.id] {
            rootEntity.removeChild(oldEntity)
        }
        entityMap[anchor.id] = entity
        rootEntity.addChild(entity)

        entityMap[anchor.id]?.transform = Transform(matrix: anchor.originFromAnchorTransform)
    }


    @MainActor
    func removePlane(_ anchor: PlaneAnchor) {
        entityMap[anchor.id]?.removeFromParent()
        entityMap.removeValue(forKey: anchor.id)
        planeAnchors.removeValue(forKey: anchor.id)
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
