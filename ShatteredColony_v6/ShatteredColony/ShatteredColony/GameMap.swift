import Foundation
import SpriteKit

// MARK: - Grid Position
struct GridPosition: Hashable, Equatable {
    let x: Int
    let y: Int
    
    func toScenePosition(tileSize: CGFloat = GridConfig.tileSize) -> CGPoint {
        return CGPoint(
            x: CGFloat(x) * tileSize + tileSize / 2,
            y: CGFloat(y) * tileSize + tileSize / 2
        )
    }
    
    static func fromScenePosition(_ point: CGPoint, tileSize: CGFloat = GridConfig.tileSize) -> GridPosition {
        return GridPosition(
            x: Int(point.x / tileSize),
            y: Int(point.y / tileSize)
        )
    }
    
    func neighbors() -> [GridPosition] {
        return [
            GridPosition(x: x - 1, y: y),
            GridPosition(x: x + 1, y: y),
            GridPosition(x: x, y: y - 1),
            GridPosition(x: x, y: y + 1)
        ]
    }
    
    func distance(to other: GridPosition) -> Int {
        return abs(x - other.x) + abs(y - other.y)
    }
    
    func isWithinRadius(_ radius: Int, of other: GridPosition) -> Bool {
        return distance(to: other) <= radius
    }
}

// MARK: - Grid Tile
class GridTile {
    let position: GridPosition
    var type: TileType
    var playerBuilding: PlayerBuilding?
    var cityBuilding: CityBuilding?  // Reference to parent city building if part of one
    
    init(position: GridPosition, type: TileType) {
        self.position = position
        self.type = type
    }
    
    var isTraversable: Bool {
        if let building = playerBuilding, building.blocksMovement {
            return false
        }
        return type.isTraversable
    }
    
    var canPlaceBuilding: Bool {
        return type == .ground && playerBuilding == nil && cityBuilding == nil
    }
}

// MARK: - City Building (2x3 with resources and zombies)
class CityBuilding {
    let id: Int
    var tiles: [GridPosition]  // All tiles this building occupies (walls)
    var doorPosition: GridPosition  // Adjacent traversable tile where door faces
    var buildingOrigin: GridPosition  // Origin of the 2x3 building
    
    var zombieCount: Int
    var resources: Resources
    var hasWorkshop: Bool = false  // Track if workshop is placed on door
    
    weak var node: SKNode?
    
    enum DoorSide {
        case north, south, east, west
    }
    
    let doorSide: DoorSide
    
    init(id: Int, origin: GridPosition, doorSide: DoorSide, zombieCount: Int, resources: Resources) {
        self.id = id
        self.buildingOrigin = origin
        self.zombieCount = zombieCount
        self.resources = resources
        self.doorSide = doorSide
        
        // Create 2x3 building tiles (all walls)
        self.tiles = []
        for dy in 0..<3 {
            for dx in 0..<2 {
                tiles.append(GridPosition(x: origin.x + dx, y: origin.y + dy))
            }
        }
        
        // Door position is OUTSIDE the building, adjacent to it
        // This is where zombies spawn and where workshop must be placed
        switch doorSide {
        case .south:
            self.doorPosition = GridPosition(x: origin.x, y: origin.y - 1)
        case .north:
            self.doorPosition = GridPosition(x: origin.x, y: origin.y + 3)
        case .west:
            self.doorPosition = GridPosition(x: origin.x - 1, y: origin.y + 1)
        case .east:
            self.doorPosition = GridPosition(x: origin.x + 2, y: origin.y + 1)
        }
    }
    
    var zombieLevel: ZombieLevel {
        switch zombieCount {
        case 0: return .absent
        case 1: return .low
        case 2: return .medium
        default: return .high
        }
    }
    
    var hasZombies: Bool { zombieCount > 0 }
    var hasResources: Bool { resources.total > 0 || resources.survivors > 0 }
    var canBeHarvested: Bool { !hasZombies && hasResources }
    
    func depositZombie() -> Bool {
        if zombieCount > 0 {
            zombieCount -= 1
            updateVisual()
            return true
        }
        return false
    }
    
    func updateVisual() {
        guard let shapeNode = node as? SKShapeNode else { return }
        shapeNode.fillColor = zombieLevel.color
    }
    
    // Check if a position is the door position (where workshop can be placed)
    func isDoorPosition(_ position: GridPosition) -> Bool {
        return position == doorPosition
    }
}

// MARK: - Bridge
class Bridge {
    let id: Int
    var tiles: [GridPosition]
    var isDestroyed: Bool = false
    
    init(id: Int, tiles: [GridPosition]) {
        self.id = id
        self.tiles = tiles
    }
}

// MARK: - Dropped Resources (from killed trucks)
class DroppedResource {
    let position: GridPosition
    var wood: Int
    var bullets: Int
    weak var node: SKNode?
    
    init(position: GridPosition, wood: Int, bullets: Int) {
        self.position = position
        self.wood = wood
        self.bullets = bullets
    }
    
    var isEmpty: Bool { wood <= 0 && bullets <= 0 }
}

// MARK: - Game Map
class GameMap {
    let width: Int
    let height: Int
    private var tiles: [[GridTile]]
    
    var cityBuildings: [CityBuilding] = []
    var bridges: [Bridge] = []
    var droppedResources: [DroppedResource] = []
    
    private var nextCityBuildingId: Int = 0
    private var nextBridgeId: Int = 0
    
    init(width: Int = GridConfig.mapWidth, height: Int = GridConfig.mapHeight) {
        self.width = width
        self.height = height
        
        tiles = (0..<height).map { y in
            (0..<width).map { x in
                GridTile(position: GridPosition(x: x, y: y), type: .ground)
            }
        }
    }
    
    // MARK: - Tile Access
    
    func tile(at position: GridPosition) -> GridTile? {
        guard isValidPosition(position) else { return nil }
        return tiles[position.y][position.x]
    }
    
    func setTile(at position: GridPosition, type: TileType) {
        guard isValidPosition(position) else { return }
        tiles[position.y][position.x].type = type
    }
    
    func isValidPosition(_ position: GridPosition) -> Bool {
        return position.x >= 0 && position.x < width &&
               position.y >= 0 && position.y < height
    }
    
    // MARK: - City Building Management
    
    @discardableResult
    func addCityBuilding(at origin: GridPosition, doorSide: CityBuilding.DoorSide = .south,
                         zombieCount: Int, resources: Resources) -> CityBuilding? {
        let building = CityBuilding(
            id: nextCityBuildingId,
            origin: origin,
            doorSide: doorSide,
            zombieCount: zombieCount,
            resources: resources
        )
        nextCityBuildingId += 1
        
        // Set all building tiles as walls
        for pos in building.tiles {
            guard let tile = tile(at: pos) else { return nil }
            tile.type = .buildingWall
            tile.cityBuilding = building
        }
        
        // Door position should remain traversable ground (it's outside the building)
        // Just mark it as associated with this building for workshop placement
        
        cityBuildings.append(building)
        return building
    }
    
    // Find city building that has its door at the given position
    func getCityBuildingWithDoor(at position: GridPosition) -> CityBuilding? {
        return cityBuildings.first { $0.doorPosition == position }
    }
    
    // Get bridge ID for dynamite position
    func getDynamiteBridgeId(at position: GridPosition) -> Int? {
        guard let tile = tile(at: position), tile.type == .dynamite else { return nil }
        // Find nearest bridge
        for bridge in bridges where !bridge.isDestroyed {
            for bridgeTile in bridge.tiles {
                if position.distance(to: bridgeTile) <= 2 {
                    return bridge.id
                }
            }
        }
        return bridges.first(where: { !$0.isDestroyed })?.id
    }
    
    func getCityBuilding(at position: GridPosition) -> CityBuilding? {
        return tile(at: position)?.cityBuilding
    }
    
    // MARK: - Bridge Management
    
    @discardableResult
    func addBridge(from start: GridPosition, to end: GridPosition) -> Bridge {
        var bridgeTiles: [GridPosition] = []
        
        // Create horizontal or vertical bridge
        if start.x == end.x {
            // Vertical bridge
            let minY = min(start.y, end.y)
            let maxY = max(start.y, end.y)
            for y in minY...maxY {
                let pos = GridPosition(x: start.x, y: y)
                setTile(at: pos, type: .bridge)
                bridgeTiles.append(pos)
            }
        } else {
            // Horizontal bridge
            let minX = min(start.x, end.x)
            let maxX = max(start.x, end.x)
            for x in minX...maxX {
                let pos = GridPosition(x: x, y: start.y)
                setTile(at: pos, type: .bridge)
                bridgeTiles.append(pos)
            }
        }
        
        let bridge = Bridge(id: nextBridgeId, tiles: bridgeTiles)
        nextBridgeId += 1
        bridges.append(bridge)
        return bridge
    }
    
    func destroyBridge(_ bridge: Bridge) {
        bridge.isDestroyed = true
        for pos in bridge.tiles {
            setTile(at: pos, type: .water)
        }
    }
    
    func getFunctionalBridges() -> [Bridge] {
        return bridges.filter { !$0.isDestroyed }
    }
    
    func getRandomFunctionalBridge() -> Bridge? {
        let functional = getFunctionalBridges()
        return functional.randomElement()
    }
    
    // MARK: - Player Building Placement
    
    func canPlacePlayerBuilding(type: PlayerBuildingType, at position: GridPosition, depots: [Depot]) -> Bool {
        // All player buildings are 1x1
        guard let tile = tile(at: position), tile.canPlaceBuilding else {
            return false
        }
        
        // Workshops must be placed on a city building's door position
        if type == .workshop {
            guard let cityBuilding = getCityBuildingWithDoor(at: position) else {
                return false
            }
            // Can't place if building already has a workshop
            if cityBuilding.hasWorkshop {
                return false
            }
        }
        
        // Check depot radius (except for depots themselves)
        if type != .depot {
            let withinDepotRadius = depots.contains { depot in
                position.isWithinRadius(GameBalance.depotBuildRadius, of: depot.gridPosition)
            }
            if !withinDepotRadius {
                return false
            }
        }
        
        return true
    }
    
    func placePlayerBuilding(_ building: PlayerBuilding, at position: GridPosition) -> Bool {
        guard let tile = tile(at: position) else { return false }
        tile.playerBuilding = building
        building.gridPosition = position
        
        // If workshop, mark the city building
        if let workshop = building as? Workshop {
            if let cityBuilding = getCityBuildingWithDoor(at: position) {
                cityBuilding.hasWorkshop = true
                workshop.targetBuilding = cityBuilding
            }
        }
        
        return true
    }
    
    func removePlayerBuilding(_ building: PlayerBuilding) {
        tile(at: building.gridPosition)?.playerBuilding = nil
        
        // If workshop, unmark the city building
        if let workshop = building as? Workshop {
            workshop.targetBuilding?.hasWorkshop = false
        }
    }
    
    private func tilesForBuilding(type: PlayerBuildingType, at position: GridPosition) -> [GridPosition] {
        // All buildings are 1x1 now
        return [position]
    }
    
    // MARK: - Dropped Resources
    
    func dropResources(at position: GridPosition, wood: Int, bullets: Int) -> DroppedResource {
        let dropped = DroppedResource(position: position, wood: wood, bullets: bullets)
        droppedResources.append(dropped)
        return dropped
    }
    
    func removeDroppedResource(_ resource: DroppedResource) {
        resource.node?.removeFromParent()
        droppedResources.removeAll { $0 === resource }
    }
    
    // MARK: - Pathfinding (A*)
    
    func findPath(from start: GridPosition, to end: GridPosition) -> [GridPosition]? {
        guard isValidPosition(start), isValidPosition(end) else { return nil }
        guard let endTile = tile(at: end), endTile.isTraversable else { return nil }
        
        var openSet: Set<GridPosition> = [start]
        var cameFrom: [GridPosition: GridPosition] = [:]
        var gScore: [GridPosition: Int] = [start: 0]
        var fScore: [GridPosition: Int] = [start: start.distance(to: end)]
        
        while !openSet.isEmpty {
            let current = openSet.min { fScore[$0, default: Int.max] < fScore[$1, default: Int.max] }!
            
            if current == end {
                return reconstructPath(cameFrom: cameFrom, current: current)
            }
            
            openSet.remove(current)
            
            for neighbor in current.neighbors() {
                guard let neighborTile = tile(at: neighbor),
                      neighborTile.isTraversable else { continue }
                
                let tentativeG = gScore[current, default: Int.max] + 1
                
                if tentativeG < gScore[neighbor, default: Int.max] {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeG
                    fScore[neighbor] = tentativeG + neighbor.distance(to: end)
                    openSet.insert(neighbor)
                }
            }
        }
        
        return nil
    }
    
    private func reconstructPath(cameFrom: [GridPosition: GridPosition], current: GridPosition) -> [GridPosition] {
        var path = [current]
        var node = current
        while let prev = cameFrom[node] {
            path.insert(prev, at: 0)
            node = prev
        }
        return path
    }
    
    // MARK: - Noise System
    
    func getCityBuildingsInRadius(of position: GridPosition, radius: Int) -> [CityBuilding] {
        return cityBuildings.filter { building in
            building.tiles.contains { $0.isWithinRadius(radius, of: position) }
        }
    }
}
