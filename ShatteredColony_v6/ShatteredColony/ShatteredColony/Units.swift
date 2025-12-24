import Foundation
import SpriteKit

// MARK: - Unit State
enum UnitState {
    case idle
    case moving
    case working
    case attacking
    case returning
    case dead
}

// MARK: - Base Mobile Unit
class MobileUnit {
    var gridPosition: GridPosition
    var state: UnitState = .idle
    weak var node: SKNode?
    
    var currentPath: [GridPosition] = []
    var pathIndex: Int = 0
    var moveProgress: CGFloat = 0
    
    init(at position: GridPosition) {
        self.gridPosition = position
    }
    
    var speed: CGFloat { UnitSpeed.survivor }  // Override in subclasses
    
    func setDestination(_ target: GridPosition, map: GameMap) -> Bool {
        guard let path = map.findPath(from: gridPosition, to: target) else {
            return false
        }
        currentPath = path
        pathIndex = 0
        state = .moving
        return true
    }
    
    func updateMovement(deltaTime: TimeInterval, gameState: GameState) {
        guard state == .moving || state == .returning,
              pathIndex < currentPath.count,
              let node = node else {
            if state == .moving { state = .idle }
            return
        }
        
        let targetGridPos = currentPath[pathIndex]
        let targetPos = targetGridPos.toScenePosition()
        
        let direction = CGPoint(
            x: targetPos.x - node.position.x,
            y: targetPos.y - node.position.y
        )
        let distance = sqrt(direction.x * direction.x + direction.y * direction.y)
        
        if distance < 2 {
            // Reached waypoint
            gridPosition = targetGridPos
            pathIndex += 1
            
            if pathIndex >= currentPath.count {
                // Reached destination
                onReachedDestination(gameState: gameState)
            }
        } else {
            // Move towards waypoint
            let moveDistance = speed * GridConfig.tileSize * CGFloat(deltaTime)
            let normalizedDir = CGPoint(x: direction.x / distance, y: direction.y / distance)
            
            node.position.x += normalizedDir.x * moveDistance
            node.position.y += normalizedDir.y * moveDistance
        }
    }
    
    func onReachedDestination(gameState: GameState) {
        state = .idle
        currentPath = []
    }
    
    func createNode() -> SKNode {
        fatalError("Subclasses must implement createNode()")
    }
}

// MARK: - Truck (carries resources)
class Truck: MobileUnit {
    var carryingWood: Int = 0
    var carryingBullets: Int = 0
    weak var sourceDepot: Depot?
    weak var targetBuilding: PlayerBuilding?
    weak var returnWorkshop: Workshop?  // For single-survivor workshop mode
    
    override var speed: CGFloat { UnitSpeed.truck }
    
    init(at position: GridPosition, sourceDepot: Depot) {
        self.sourceDepot = sourceDepot
        super.init(at: position)
    }
    
    var isCarryingResources: Bool {
        return carryingWood > 0 || carryingBullets > 0
    }
    
    override func createNode() -> SKNode {
        let node = SKShapeNode(circleOfRadius: 6)
        node.fillColor = SKColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        node.strokeColor = .yellow
        node.lineWidth = 2
        node.position = gridPosition.toScenePosition()
        node.zPosition = ZPosition.units
        
        self.node = node
        return node
    }
    
    override func onReachedDestination(gameState: GameState) {
        // Deliver resources to target building
        if let building = targetBuilding {
            if carryingWood > 0 {
                building.receiveWood(carryingWood)
            }
            if carryingBullets > 0 {
                building.receiveBullets(carryingBullets)
            }
            
            // If this is a depot, survivor returns
            if let depot = building as? Depot {
                depot.depositSurvivor()
            } else if let depot = sourceDepot {
                // Return to source depot or workshop
                if let workshop = returnWorkshop {
                    // Return to workshop
                    workshop.presentSurvivors += 1
                } else {
                    depot.depositSurvivor()
                }
            }
        }
        
        carryingWood = 0
        carryingBullets = 0
        
        gameState.removeTruck(self)
    }
    
    func dropResources(gameState: GameState) {
        if isCarryingResources {
            let dropped = gameState.map.dropResources(
                at: gridPosition,
                wood: carryingWood,
                bullets: carryingBullets
            )
            gameState.addDroppedResource(dropped)
            carryingWood = 0
            carryingBullets = 0
        }
    }
    
    func update(deltaTime: TimeInterval, gameState: GameState) {
        updateMovement(deltaTime: deltaTime, gameState: gameState)
        
        if state == .moving {
            gameState.createNoiseEvent(at: gridPosition, level: .low)
        }
    }
}

// MARK: - Zombie
class Zombie: MobileUnit {
    let zombieType: ZombieType
    var currentNoiseLevel: NoiseLevel = .none
    var noiseTarget: GridPosition?
    var targetDepot: Depot?  // For bridge zombies
    var isDead: Bool = false
    
    private var attackTimer: TimeInterval = 0
    private let attackInterval: TimeInterval = 1.0
    
    override var speed: CGFloat { UnitSpeed.zombie }
    
    init(at position: GridPosition, type: ZombieType = .normal) {
        self.zombieType = type
        super.init(at: position)
    }
    
    override func createNode() -> SKNode {
        let node = SKShapeNode(circleOfRadius: 7)
        
        // Bridge zombies are slightly different color
        if zombieType == .bridge {
            node.fillColor = SKColor(red: 0.6, green: 0.5, blue: 0.5, alpha: 1.0)
        } else {
            node.fillColor = SKColor(red: 0.5, green: 0.6, blue: 0.5, alpha: 1.0)
        }
        node.strokeColor = SKColor(red: 0.3, green: 0.4, blue: 0.3, alpha: 1.0)
        node.lineWidth = 2
        node.position = gridPosition.toScenePosition()
        node.zPosition = ZPosition.units
        
        self.node = node
        return node
    }
    
    func update(deltaTime: TimeInterval, gameState: GameState) {
        guard !isDead else { return }
        
        switch state {
        case .moving:
            updateMovement(deltaTime: deltaTime, gameState: gameState)
            checkForTargets(gameState: gameState)
            
        case .attacking:
            updateAttacking(deltaTime: deltaTime, gameState: gameState)
            
        case .idle:
            if zombieType == .bridge && targetDepot != nil {
                // Bridge zombie: path to depot
                if let depot = targetDepot {
                    _ = setDestination(depot.gridPosition, map: gameState.map)
                }
            }
            // Normal zombies wait for noise
            
        default:
            break
        }
    }
    
    func respondToNoise(level: NoiseLevel, source: GridPosition, gameState: GameState) {
        // Only respond if new noise is higher priority
        guard level > currentNoiseLevel || state == .idle else { return }
        
        // Bridge zombies that haven't reached their depot ignore noise
        if zombieType == .bridge && targetDepot != nil && !targetDepot!.isDestroyed {
            return
        }
        
        currentNoiseLevel = level
        noiseTarget = source
        _ = setDestination(source, map: gameState.map)
    }
    
    private func checkForTargets(gameState: GameState) {
        guard let node = node else { return }
        
        // Check for trucks to infect
        for truck in gameState.trucks {
            guard let truckNode = truck.node else { continue }
            let distance = node.position.distance(to: truckNode.position)
            
            if distance < GridConfig.tileSize {
                // Infect truck
                truck.dropResources(gameState: gameState)
                gameState.removeTruck(truck)
                gameState.spawnZombie(at: truck.gridPosition, type: .normal)
                return
            }
        }
        
        // Check for buildings to attack
        if let tile = gameState.map.tile(at: gridPosition),
           let building = tile.playerBuilding {
            state = .attacking
            currentPath = []
        }
    }
    
    private func updateAttacking(deltaTime: TimeInterval, gameState: GameState) {
        attackTimer += deltaTime
        
        guard attackTimer >= attackInterval else { return }
        attackTimer = 0
        
        // Find building at current position
        guard let tile = gameState.map.tile(at: gridPosition),
              let building = tile.playerBuilding else {
            state = .idle
            return
        }
        
// --- FIX START ---
        if let barricade = building as? Barricade {
            barricade.takeDamage(1)
        } else {
            // Non-barricades have 1 HP: set resources to 0 to destroy
            building.presentSurvivors = 0
            building.presentWood = 0
        }
        // --- FIX END ---



        // Deal damage
        building.takeDamage(1)
        
        if building.isDestroyed {
            gameState.destroyPlayerBuilding(building)
            
            // If this was our target depot (bridge zombie), become normal
            if let depot = building as? Depot, depot === targetDepot {
                targetDepot = nil
            }
            
            state = .idle
            currentNoiseLevel = .none
        }
    }
    
    override func onReachedDestination(gameState: GameState) {
        // Check if there's a building to attack here
        if let tile = gameState.map.tile(at: gridPosition),
           tile.playerBuilding != nil {
            state = .attacking
        } else {
            state = .idle
            currentNoiseLevel = .none
            noiseTarget = nil
        }
    }
}

// MARK: - Free Survivor (not in truck, just running)
class FreeSurvivor: MobileUnit {
    weak var destinationDepot: Depot?
    weak var destinationBuilding: PlayerBuilding?
    
    override var speed: CGFloat { UnitSpeed.survivor }
    
    override func createNode() -> SKNode {
        let node = SKShapeNode(circleOfRadius: 5)
        node.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
        node.strokeColor = .white
        node.lineWidth = 1
        node.position = gridPosition.toScenePosition()
        node.zPosition = ZPosition.units
        
        self.node = node
        return node
    }
    
    func update(deltaTime: TimeInterval, gameState: GameState) {
        updateMovement(deltaTime: deltaTime, gameState: gameState)
        
        // Create low noise while moving
        if state == .moving {
            gameState.createNoiseEvent(at: gridPosition, level: .low)
        }
    }
    
    override func onReachedDestination(gameState: GameState) {
        // Arrive at building
        if let building = destinationBuilding {
            building.receiveSurvivor()
            gameState.removeFreeSurvivor(self)
            return
        }
        
        // Arrive at depot
        if let depot = destinationDepot {
            depot.depositSurvivor()
        }
        gameState.removeFreeSurvivor(self)
    }
}
