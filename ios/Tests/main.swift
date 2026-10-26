import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
var state = GameState()
check(!state.interact(at: 2), "Food must unlock after heat")
for _ in 0..<15 { check(state.interact(at: 0), "Gather capacity") }
check(!state.interact(at: 0), "Cannot overfill")
for _ in 0..<9 { _ = state.interact(at: 1) }
check(state.fuel == 100 && state.wood == 6, "Fuel is bounded and delivery conserves wood")
for _ in 0..<6 { _ = state.interact(at: 2) }
check(!state.interact(at: 2), "Food target prevents unused inventory accumulation")
check(!state.interact(at: 4), "Repair gated by feeding")
for _ in 0..<6 { _ = state.interact(at: 3) }
for _ in 0..<6 { _ = state.interact(at: 4) }
check(state.wood == 0 && state.repairWood == 6, "Partial construction preserves paid materials")
let encoded = try JSONEncoder().encode(state)
state = try JSONDecoder().decode(GameState.self, from: encoded)
check(state.valid && state.repairWood == 6, "Save round trip")
for _ in 0..<6 { _ = state.interact(at: 0); _ = state.interact(at: 4) }
check(state.repaired && !state.interact(at: 4), "Upgrade completes once")
state.wood = -1
check(!state.valid, "Reject negative inventories")
state.wood = 0; state.version = 99
check(!state.valid, "Reject unknown versions")
print("Native simulation checks passed")

// Sequential native schema migration preserves earlier payments and carried resources.
let legacy = Data("""
{"version":1,"wood":2,"food":1,"fuel":20,"deliveredFood":3,"repairWood":0,"restored":true,"x":0,"z":4}
""".utf8)
var migrated = try JSONDecoder().decode(GameState.self, from: legacy)
check(migrated.version == 2 && migrated.wood == 2 && migrated.food == 1 && migrated.valid, "Version 1 migration")
migrated.deliveredFood = 6; migrated.repairWood = 12; migrated.worker = true
for _ in 0..<40 { migrated.tick(0.1) }
check(migrated.stock == 1, "Warm worker production")
let beforeWood = migrated.wood
check(migrated.interact(at:4) && migrated.stock == 0 && migrated.wood == beforeWood + 1, "Worker stock physically collected")
migrated.wood = Int.max
check(!migrated.valid, "Reject extreme inventory without overflow")
print("Native migration and worker checks passed")
