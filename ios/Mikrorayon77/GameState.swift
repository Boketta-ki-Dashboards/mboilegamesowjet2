import Foundation

// Prototype tuning, not final campaign balance. Independent of rendering and UIKit.
struct GameState: Codable {
    var version = 2
    var wood = 0
    var food = 0
    var fuel: Double = 0
    var deliveredFood = 0
    var repairWood = 0
    var restored = false
    var x: Float = 0
    var z: Float = 10
    var worker = false
    var stock = 0
    var workerTime: Double = 0
    var talked: [String] = []
    var capacity: Int { 15 }
    var repaired: Bool { repairWood >= 12 }
    var objective: String {
        if !restored { return wood < 5 ? "Sammle 5 Holz · links bei den Bäumen" : "Bringe Holz zur Heizung · orange Zone" }
        if deliveredFood < 6 { return "Versorge die Bewohner · 6 Nahrung zur Kantine" }
        if !repaired { return "Repariere den Unterstand · 12 Holz zur Bauzone" }
        return worker ? "Juri sägt Holz · Vorrat \(stock)/30 · an der Werkstatt abholen" : "Sprich mit Juri · weise ihm die Werkstatt zu"
    }
    mutating func interact(at site: Int) -> Bool {
        switch site {
        case 0 where wood + food < capacity: wood += 1
        case 1 where wood > 0 && fuel < 100:
            wood -= 1; fuel = min(100, fuel + 12); restored = true
        case 2 where restored && deliveredFood + food < 6 && wood + food < capacity: food += 1
        case 3 where food > 0 && deliveredFood < 6: food -= 1; deliveredFood += 1
        case 4 where deliveredFood >= 6 && wood > 0 && !repaired: wood -= 1; repairWood += 1
        case 4 where repaired && stock > 0 && wood + food < capacity: wood += 1; stock -= 1
        default: return false
        }
        return true
    }
    mutating func tick(_ dt: Double) {
        fuel = max(0, fuel - dt * 0.12)
        if worker && stock < 30 {
            workerTime += dt * (fuel > 0 ? 1 : 0.6)
            if workerTime >= 4 { workerTime -= 4; stock += 1 }
        }
    }
    enum CodingKeys: String, CodingKey {
        case version, wood, food, fuel, deliveredFood, repairWood, restored, x, z, worker, stock, workerTime, talked
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        wood = try c.decode(Int.self, forKey: .wood); food = try c.decode(Int.self, forKey: .food)
        fuel = try c.decode(Double.self, forKey: .fuel); deliveredFood = try c.decode(Int.self, forKey: .deliveredFood)
        repairWood = try c.decode(Int.self, forKey: .repairWood); restored = try c.decode(Bool.self, forKey: .restored)
        x = try c.decode(Float.self, forKey: .x); z = try c.decode(Float.self, forKey: .z)
        worker = try c.decodeIfPresent(Bool.self, forKey: .worker) ?? false
        stock = try c.decodeIfPresent(Int.self, forKey: .stock) ?? 0
        workerTime = try c.decodeIfPresent(Double.self, forKey: .workerTime) ?? 0
        talked = try c.decodeIfPresent([String].self, forKey: .talked) ?? []
        if version == 1 { version = 2 } // Preserve inventory and paid construction from the first native test.
    }
    var valid: Bool {
        version == 2 && (0...30).contains(stock) && workerTime.isFinite && workerTime >= 0 && workerTime < 4 && (!worker || repaired) && wood >= 0 && wood <= 15 && food >= 0 && food <= 15 && wood + food <= 15 && fuel.isFinite && fuel >= 0 && fuel <= 100 && (0...6).contains(deliveredFood) && (0...12).contains(repairWood) && x.isFinite && z.isFinite && abs(x) <= 19 && z >= -14 && z <= 21
    }
}

final class SaveStore {
    private let key = "m77.native.courtyard.v1"
    private(set) var writable = true
    func load() -> GameState {
        guard let data = UserDefaults.standard.data(forKey: key) else { return GameState() }
        guard let state = try? JSONDecoder().decode(GameState.self, from: data), state.valid else {
            // Preserve unrecognised/corrupt data instead of replacing it with a fresh game.
            writable = false
            return GameState()
        }
        return state
    }
    func save(_ state: GameState) {
        guard writable, state.valid, let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
