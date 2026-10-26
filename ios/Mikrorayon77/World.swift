import SceneKit
import UIKit

struct ContentNode: Decodable {
    var name: String
    var p: [Float]?
    var r: [Float]?
    var s: [Float]?
    var shape: String?
    var color: String?
    var emit: Bool?
    var text: String?
    var fontSize: Float?
    var children: [ContentNode]?
}
struct DistrictSite: Decodable { var id: String; var p: [Float]; var title: String }
struct DistrictNPC: Decodable { var id: String; var name: String; var role: String; var p: [Float]; var dialogue: String }
struct DistrictEgg: Decodable { var p: [Float]; var title: String; var text: String }
struct DistrictContent: Decodable {
    var world: ContentNode
    var models: [String: ContentNode]
    var sites: [DistrictSite]
    var npcs: [DistrictNPC]
    var lamps: [[Float]]
    var colliders: [[Float]]
    var easterEggs: [DistrictEgg]
}

final class World {
    let scene = SCNScene()
    let player = SCNNode()
    let camera = SCNNode()
    let stack = SCNNode()
    let fire = SCNNode()
    let shelter = SCNNode()
    var residents: [SCNNode] = []
    private(set) var content: DistrictContent?
    private(set) var loadError: String?
    private var model = SCNNode()
    private var repair = SCNNode()
    private var lastCarry = -1
    private var lastRepair = -1
    private var materials: [String: SCNMaterial] = [:]
    var sites: [SCNVector3] { content?.sites.map { vector($0.p) } ?? [] }
    private let amber = UIColor(red: 1, green: 0.63, blue: 0.24, alpha: 1)
    func vector(_ a: [Float]) -> SCNVector3 { SCNVector3(a[0], a[1], a[2]) }
    func color(_ hex: String) -> UIColor {
        let n = UInt32(hex, radix: 16) ?? 0xffffff
        return UIColor(red: CGFloat((n >> 16) & 255)/255, green: CGFloat((n >> 8) & 255)/255, blue: CGFloat(n & 255)/255, alpha: 1)
    }
    private func material(_ d: ContentNode) -> SCNMaterial {
        let key = (d.color ?? "ffffff") + String(d.emit ?? false)
        if let existing = materials[key] { return existing }
        let m = SCNMaterial(); m.diffuse.contents = color(d.color ?? "ffffff")
        if let url = Bundle.main.url(forResource:d.color ?? "ffffff",withExtension:"png",subdirectory:"Content"), let texture = UIImage(contentsOfFile:url.path) {
            m.diffuse.contents = texture
        }
        m.lightingModel = .physicallyBased; m.roughness.contents = 0.94
        if d.emit == true { m.emission.contents = color(d.color ?? "ffffff"); m.emission.intensity = 0.65 }
        materials[key] = m; return m
    }
    private func node(_ d: ContentNode) -> SCNNode {
        let n = SCNNode(); n.name = d.name
        switch d.shape {
        case "box": n.geometry = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        case "sphere":
            let sphere = SCNSphere(radius: 0.5); sphere.segmentCount = 12; n.geometry = sphere
        case "cylinder", "cone":
            let cone = SCNCone(topRadius: d.shape == "cone" ? 0.29 : 0.5, bottomRadius: 0.5, height: 1)
            cone.radialSegmentCount = 12; n.geometry = cone
        default: break
        }
        if let words = d.text {
            let text = SCNText(string: words, extrusionDepth: 0)
            text.font = UIFont.systemFont(ofSize: CGFloat(d.fontSize ?? 0.35), weight: .semibold)
            text.flatness = 0.2; n.geometry = text
        }
        n.geometry?.materials = [material(d)]
        n.position = vector(d.p ?? [0,0,0]); n.eulerAngles = vector(d.r ?? [0,0,0]); n.scale = vector(d.s ?? [1,1,1])
        for c in d.children ?? [] { n.addChildNode(node(c)) }
        return n
    }
    init() {
        do {
            guard let url = Bundle.main.url(forResource: "district", withExtension: "json", subdirectory: "Content") else {
                throw NSError(domain: "District", code: 1, userInfo: [NSLocalizedDescriptionKey: "Content/district.json fehlt im App-Bundle"])
            }
            let decoded = try JSONDecoder().decode(DistrictContent.self, from: Data(contentsOf: url))
            content = decoded
            // Static authored geometry shares source with the runnable Linux review.
            scene.rootNode.addChildNode(node(decoded.world).flattenedClone())
            if let officer = decoded.models["officer"] { model = node(officer); player.addChildNode(model) }
            for data in decoded.npcs {
                guard let prefab = decoded.models[data.id] else { continue }
                let npc = node(prefab); npc.position = vector(data.p); scene.rootNode.addChildNode(npc); residents.append(npc)
            }
            if let prefab = decoded.models["repair"] { repair = node(prefab); repair.position = SCNVector3(-11,0,10); scene.rootNode.addChildNode(repair) }
            for p in decoded.lamps {
                let lamp = SCNNode(); lamp.position = vector(p); lamp.light = SCNLight(); lamp.light?.type = .omni
                lamp.light?.color = amber; lamp.light?.intensity = 180; lamp.light?.attenuationEndDistance = 6
                scene.rootNode.addChildNode(lamp)
            }
            for p in sites {
                let shape = SCNTorus(ringRadius: 1.2, pipeRadius: 0.025)
                shape.firstMaterial?.diffuse.contents = amber
                let zone = SCNNode(geometry: shape); zone.position = SCNVector3(p.x,0.04,p.z); scene.rootNode.addChildNode(zone)
            }
        } catch { loadError = error.localizedDescription }
        scene.background.contents = color("56636b")
        scene.fogColor = color("859299"); scene.fogStartDistance = 55; scene.fogEndDistance = 140
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.color = color("aebdc8"); ambient.light?.intensity = 350; scene.rootNode.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional
        sun.light?.intensity = 650; sun.light?.color = color("d4d6c5"); sun.eulerAngles = SCNVector3(-0.84,-0.56,0)
        sun.light?.castsShadow = true; sun.light?.shadowMapSize = CGSize(width:1024,height:1024)
        sun.light?.shadowColor = UIColor(white:0,alpha:0.35); scene.rootNode.addChildNode(sun)
        camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 20; camera.camera?.zFar = 150
        scene.rootNode.addChildNode(camera)
        stack.position = SCNVector3(0,1.05,-0.4); player.addChildNode(stack); scene.rootNode.addChildNode(player)
        fire.geometry = SCNSphere(radius:0.3); fire.geometry?.firstMaterial?.diffuse.contents = amber; fire.geometry?.firstMaterial?.emission.contents = amber
        fire.position = SCNVector3(-10,0.8,-5.85); fire.light = SCNLight(); fire.light?.type = .omni
        fire.light?.color = amber; fire.light?.attenuationEndDistance = 8; scene.rootNode.addChildNode(fire)
        let flakes = SCNParticleSystem(); flakes.birthRate = 14; flakes.particleLifeSpan = 8
        flakes.particleSize = 0.035; flakes.particleColor = color("dce5e4")
        flakes.emitterShape = SCNBox(width:42,height:0.1,length:40,chamferRadius:0)
        flakes.particleVelocity = 1.5; flakes.emittingDirection = SCNVector3(0,-1,0)
        let snowfall = SCNNode(); snowfall.position.y = 12; snowfall.addParticleSystem(flakes); scene.rootNode.addChildNode(snowfall)
    }
    func blocked(x: Float, z: Float) -> Bool {
        if x < -19 || x > 19 || z < -14 || z > 21 { return true }
        return content?.colliders.contains { abs(x-$0[0]) < $0[2]/2+0.35 && abs(z-$0[1]) < $0[3]/2+0.35 } ?? true
    }
    func nearestNPC(x: Float, z: Float) -> Int? {
        residents.indices.first { hypot(residents[$0].position.x-x, residents[$0].position.z-z) < 2.8 }
    }
    func nearestEgg(x: Float, z: Float) -> Int? {
        content?.easterEggs.indices.first { i in
            guard let p = content?.easterEggs[i].p else { return false }
            return hypot(p[0]-x, p[2]-z) < 2.5
        }
    }
    func sync(_ state: GameState, time: Double, moving: Bool) {
        player.position = SCNVector3(state.x,0,state.z)
        let focus = SCNVector3(state.x,0,state.z-2)
        camera.position = SCNVector3(focus.x+14,26,focus.z+28); camera.look(at:focus)
        fire.isHidden = state.fuel <= 0; fire.light?.intensity = state.fuel > 0 ? 500 : 0
        for part in ["left_leg","right_leg","left_arm","right_arm"] {
            let sign: Float = part.hasPrefix("left") ? 1 : -1
            model.childNode(withName:part,recursively:false)?.eulerAngles.x = moving ? Float(sin(time*9))*0.43*sign*(part.hasSuffix("leg") ? 1 : -1) : 0
        }
        if !moving && hypot(state.x+11,state.z-4)<1.65 && state.wood+state.food<15 {
            model.childNode(withName:"right_arm",recursively:false)?.eulerAngles.x = -0.7+Float(sin(time*13))*0.7
        }
        for (i,npc) in residents.enumerated() {
            npc.childNode(withName:"bowl",recursively:true)?.isHidden = state.deliveredFood < 6
            npc.childNode(withName:"right_arm",recursively:false)?.eulerAngles.x = state.deliveredFood >= 6 ? -0.7 : 0
            npc.eulerAngles.z = state.fuel <= 0 ? Float(sin(time*8+Double(i)))*0.015 : 0
            if i == 2 && state.worker {
                let phase = Float((sin(time*0.52)+1)/2)
                npc.position = SCNVector3(-11+phase,0,7+phase*4.8)
                npc.childNode(withName:"left_leg",recursively:false)?.eulerAngles.x = Float(sin(time*7))*0.4
                npc.childNode(withName:"right_leg",recursively:false)?.eulerAngles.x = -Float(sin(time*7))*0.4
            }
        }
        let count = state.wood+state.food
        if count != lastCarry {
            stack.childNodes.forEach { $0.removeFromParentNode() }
            for i in 0..<count {
                let item = SCNNode()
                if i < state.wood { item.geometry = SCNCylinder(radius:0.09,height:0.65); item.eulerAngles.z = .pi/2 }
                else { item.geometry = SCNBox(width:0.5,height:0.14,length:0.35,chamferRadius:0.01) }
                item.geometry?.firstMaterial?.diffuse.contents = color(i < state.wood ? "92745b" : "8c9c66")
                item.position.y = Float(i)*0.15; stack.addChildNode(item)
            }
            lastCarry = count
        }
        if lastRepair != state.repairWood {
            for (i,n) in repair.childNodes.enumerated() { n.isHidden = i < 8 ? i >= state.repairWood*8/12 : !state.repaired }
            lastRepair = state.repairWood
        }
    }
}
