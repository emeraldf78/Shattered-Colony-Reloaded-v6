import Foundation
import SpriteKit

// MARK: - Grid Configuration
struct GridConfig {
    static let tileSize: CGFloat = 16.0
    static let mapWidth: Int = 64
    static let mapHeight: Int = 64
}

// MARK: - Tile Types
enum TileType: Int, CaseIterable {
    case ground = 0
    case buildingWall = 1
    case buildingDoor = 2
    case water = 3
    case bridge = 4
    case debris = 5          // Can place workshop to clear
    case dynamite = 6        // Bridge dynamite point
    
    var isTraversable: Bool {
        switch self {
        case .ground, .buildingDoor, .bridge, .dynamite:
            return true
        case .buildingWall, .water, .debris:
            return false
        }
    }
    
    var canPlaceWorkshop: Bool {
        switch self {
        case .buildingDoor, .debris, .dynamite:
            return true
        default:
            return false
        }
    }
    
    var color: SKColor {
        switch self {
        case .ground:       return SKColor(red: 0.45, green: 0.36, blue: 0.28, alpha: 1.0)
        case .buildingWall: return SKColor(red: 0.35, green: 0.35, blue: 0.4, alpha: 1.0)
        case .buildingDoor: return SKColor(red: 0.5, green: 0.4, blue: 0.3, alpha: 1.0)
        case .water:        return SKColor(red: 0.2, green: 0.4, blue: 0.7, alpha: 1.0)
        case .bridge:       return SKColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1.0)
        case .debris:       return SKColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0)
        case .dynamite:     return SKColor(red: 0.7, green: 0.3, blue: 0.2, alpha: 1.0)
        }
    }
}

// MARK: - Player Building Types
enum PlayerBuildingType: CaseIterable {
    case workshop
    case depot
    case sniperTower
    case barricade
    
    var color: SKColor {
        switch self {
        case .workshop:     return SKColor(red: 0.9, green: 0.7, blue: 0.2, alpha: 1.0)
        case .depot:        return SKColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1.0)
        case .sniperTower:  return SKColor(red: 0.5, green: 0.2, blue: 0.5, alpha: 1.0)
        case .barricade:    return SKColor(red: 0.7, green: 0.5, blue: 0.3, alpha: 1.0)
        }
    }
    
    var size: CGSize {
        let tile = GridConfig.tileSize
        return CGSize(width: tile, height: tile)
    }
    
    var woodCost: Int {
        switch self {
        case .workshop:     return 20
        case .depot:        return 50
        case .sniperTower:  return 40
        case .barricade:    return 10
        }
    }
    
    var hasAreaOfEffect: Bool {
        switch self {
        case .sniperTower, .depot:
            return true
        default:
            return false
        }
    }
    
    var areaOfEffectRadius: Int {
        switch self {
        case .sniperTower:  return GameBalance.sniperRange
        case .depot:        return GameBalance.depotBuildRadius
        default:            return 0
        }
    }
}

// MARK: - Noise System
enum NoiseLevel: Int, Comparable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    
    static func < (lhs: NoiseLevel, rhs: NoiseLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var triggerChance: CGFloat {
        switch self {
        case .none:   return 0.0
        case .low:    return 0.20
        case .medium: return 0.40
        case .high:   return 1.0
        }
    }
    
    var radius: Int {
        switch self {
        case .none:   return 0
        case .low:    return 2
        case .medium: return 4
        case .high:   return 8
        }
    }
}

// MARK: - City Building Zombie Levels
enum ZombieLevel: Int, CaseIterable {
    case absent = 0
    case low = 1
    case medium = 2
    case high = 3
    
    var zombieCount: Int {
        return self.rawValue
    }
    
    var color: SKColor {
        switch self {
        case .absent: return SKColor(red: 0.3, green: 0.5, blue: 0.3, alpha: 1.0)
        case .low:    return SKColor(red: 0.5, green: 0.5, blue: 0.3, alpha: 1.0)
        case .medium: return SKColor(red: 0.6, green: 0.4, blue: 0.3, alpha: 1.0)
        case .high:   return SKColor(red: 0.6, green: 0.3, blue: 0.3, alpha: 1.0)
        }
    }
}

// MARK: - Resources
struct Resources {
    var wood: Int = 0
    var bullets: Int = 0
    var survivors: Int = 0
    
    static let zero = Resources()
    
    var total: Int { wood + bullets }
    
    static func + (lhs: Resources, rhs: Resources) -> Resources {
        return Resources(
            wood: lhs.wood + rhs.wood,
            bullets: lhs.bullets + rhs.bullets,
            survivors: lhs.survivors + rhs.survivors
        )
    }
    
    static func - (lhs: Resources, rhs: Resources) -> Resources {
        return Resources(
            wood: max(0, lhs.wood - rhs.wood),
            bullets: max(0, lhs.bullets - rhs.bullets),
            survivors: max(0, lhs.survivors - rhs.survivors)
        )
    }
}

// MARK: - Unit Speeds (blocks per second)
struct UnitSpeed {
    static let survivor: CGFloat = 2.0
    static let truck: CGFloat = 2.0
    static let zombie: CGFloat = 1.5
}

// MARK: - Game Balance
struct GameBalance {
    // Round timer
    static let roundDuration: TimeInterval = 180.0
    static let bridgeZombieSpawnCount: Int = 10
    
    // Depot
    static let depotBuildRadius: Int = 8
    static let freeDepotSurvivors: Int = 5
    static let freeDepotWood: Int = 50
    static let freeDepotBullets: Int = 50
    
    // Workshop
    static let workshopMediumNoiseThreshold: Int = 20
    static let workshopMaxTrucksPerSecond: Int = 5
    static let dynamiteCharges: Int = 200
    static let workshopSurvivorDeathChance: CGFloat = 0.10  // 10% per zombie
    
    // Sniper
    static let sniperRange: Int = 8
    static let sniperMaxSurvivors: Int = 11
    static let sniperFireRate: TimeInterval = 1.0
    
    // Truck
    static let truckCapacity: Int = 10
    
    // Barricade
    static let barricadeBaseHealth: Int = 0  // Health = wood assigned
    
    // Noise radii
    static let bridgeDestructionNoiseRadius: Int = 12
    static let shootingNoiseRadius: Int = 8
    static let workshopNoiseRadius: Int = 4
    static let movementNoiseRadius: Int = 2
    
    // Prioritization
    static let prioritizationDuration: TimeInterval = 30.0
}

// MARK: - Time Control
enum TimeSpeed: CGFloat {
    case paused = 0.0
    case normal = 1.0
    case fast = 2.0
    case veryFast = 4.0
    
    var displayName: String {
        switch self {
        case .paused:   return "⏸"
        case .normal:   return "1x"
        case .fast:     return "2x"
        case .veryFast: return "4x"
        }
    }
}

// MARK: - Zombie Types
enum ZombieType {
    case normal
    case bridge
}

// MARK: - Placement Error
enum PlacementError {
    case none
    case outOfRange
    case invalidLocation
    case nothingToScavenge
    case alreadyHasWorkshop
    
    var message: String {
        switch self {
        case .none: return ""
        case .outOfRange: return "Can't place: Out of depot range"
        case .invalidLocation: return "Can't place: Invalid location"
        case .nothingToScavenge: return "Can't place: Nothing to scavenge"
        case .alreadyHasWorkshop: return "Can't place: Workshop already exists"
        }
    }
}

// MARK: - Prioritization
enum PrioritizationMode {
    case none
    case boost          // 30 seconds
    case heavyPour      // Indefinite
}

enum FlowDirection {
    case toTarget
    case toSource
}

struct DepotPrioritization {
    var targetBuilding: PlayerBuilding
    var mode: PrioritizationMode
    var flowPercent: CGFloat  // 0.5, 0.75, or 1.0
    var flowDirection: FlowDirection
    var timeRemaining: TimeInterval?  // nil for heavy pour
}

// MARK: - Z Positions (render order)
struct ZPosition {
    static let terrain: CGFloat = 0
    static let areaOfEffect: CGFloat = 5
    static let buildings: CGFloat = 10
    static let cityBuildings: CGFloat = 15
    static let playerBuildings: CGFloat = 20
    static let droppedResources: CGFloat = 25
    static let units: CGFloat = 30
    static let projectiles: CGFloat = 40
    static let connectionLines: CGFloat = 45
    static let buildingIndicators: CGFloat = 48
    static let uiBackground: CGFloat = 90
    static let ui: CGFloat = 100
    static let popup: CGFloat = 150
}

// MARK: - CGPoint Extension
extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
    
    func gridDistance(to other: CGPoint) -> Int {
        let dx = abs(Int(other.x / GridConfig.tileSize) - Int(x / GridConfig.tileSize))
        let dy = abs(Int(other.y / GridConfig.tileSize) - Int(y / GridConfig.tileSize))
        return dx + dy
    }
}
