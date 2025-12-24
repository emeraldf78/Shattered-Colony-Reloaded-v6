import Foundation
import SpriteKit

// MARK: - Base Player Building
class PlayerBuilding {
    let type: PlayerBuildingType
    var gridPosition: GridPosition = GridPosition(x: 0, y: 0)
    weak var node: SKNode?
    weak var sourceDepot: Depot?
    
    // Quota system (what's assigned/requested)
    var survivorQuota: Int = 0
    var woodQuota: Int = 0
    var bulletQuota: Int = 0
    
    // Actual present resources
    var presentSurvivors: Int = 0
    var presentWood: Int = 0
    var presentBullets: Int = 0
    
    // Status indicators
    var indicatorNode: SKNode?
    
    init(type: PlayerBuildingType) {
        self.type = type
    }
    
    var blocksMovement: Bool {
        return type == .barricade
    }
    
    var isDestroyed: Bool { false }
    
    // Check if building needs resources
    var needsSurvivors: Bool { presentSurvivors < survivorQuota }
    var needsWood: Bool { presentWood < woodQuota }
    var needsBullets: Bool { presentBullets < bulletQuota }
    var needsAnyResource: Bool { needsSurvivors || needsWood || needsBullets }
    
    // Calculate deficit for prioritization
    var survivorDeficit: Int { max(0, survivorQuota - presentSurvivors) }
    var woodDeficit: Int { max(0, woodQuota - presentWood) }
    var bulletDeficit: Int { max(0, bulletQuota - presentBullets) }
    var totalDeficit: Int { survivorDeficit + woodDeficit + bulletDeficit }
    
    func createNode() -> SKNode {
        let node = SKShapeNode(rectOf: type.size)
        node.fillColor = type.color
        node.strokeColor = .white
        node.lineWidth = 1
        node.position = gridPosition.toScenePosition()
        node.zPosition = ZPosition.playerBuildings
        
        self.node = node
        return node
    }
    
    func update(deltaTime: TimeInterval, gameState: GameState) {
        updateIndicator()
    }
    
    func updateIndicator() {
        indicatorNode?.removeFromParent()
        indicatorNode = nil
        
        guard needsAnyResource, let parentNode = node else { return }
        
        let indicator = SKLabelNode(fontNamed: "Apple Color Emoji")
        indicator.fontSize = 10
        
        if needsSurvivors {
            indicator.text = "👩🏿"
        } else if needsBullets {
            indicator.text = "🔫"
        } else if needsWood {
            indicator.text = "🪵"
        }
        
        indicator.position = CGPoint(x: 0, y: 8)
        indicator.zPosition = ZPosition.buildingIndicators
        parentNode.addChild(indicator)
        indicatorNode = indicator
    }
    
    func receiveSurvivor() {
        presentSurvivors += 1
        updateIndicator()
    }
    
    func receiveWood(_ amount: Int) {
        presentWood += amount
        updateIndicator()
    }
    
    func receiveBullets(_ amount: Int) {
        presentBullets += amount
        updateIndicator()
    }
    
    func retreat(gameState: GameState) {
        // Override in subclasses
    }
}

// MARK: - Depot
class Depot: PlayerBuilding {
    var storedWood: Int = 0
    var storedBullets: Int = 0
    var heldSurvivors: Int = 0
    
    var prioritizations: [DepotPrioritization] = []
    var showDependencies: Bool = false
    var hasHeavyPour: Bool = false
    var connectionLines: [SKNode] = []
    
    init() {
        super.init(type: .depot)
    }
    
    override func createNode() -> SKNode {
        let node = super.createNode()
        
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 8
        label.fontColor = .white
        label.text = "👤\(heldSurvivors)"
        label.verticalAlignmentMode = .center
        label.name = "survivorLabel"
        node.addChild(label)
        
        return node
    }
    
    func updateLabel() {
        if let label = node?.childNode(withName: "survivorLabel") as? SKLabelNode {
            label.text = "👤\(heldSurvivors)"
        }
        
        // Heavy pour indicator
        if hasHeavyPour {
            if node?.childNode(withName: "heavyPourIndicator") == nil {
                let indicator = SKLabelNode(fontNamed: "Apple Color Emoji")
                indicator.text = "🌠"
                indicator.fontSize = 10
                indicator.position = CGPoint(x: 8, y: 8)
                indicator.name = "heavyPourIndicator"
                node?.addChild(indicator)
            }
        } else {
            node?.childNode(withName: "heavyPourIndicator")?.removeFromParent()
        }
    }
    
    func depositSurvivor() {
        heldSurvivors += 1
        updateLabel()
    }
    
    func withdrawSurvivor() -> Bool {
        if heldSurvivors > 0 {
            heldSurvivors -= 1
            updateLabel()
            return true
        }
        return false
    }
    
    func storeResources(wood: Int = 0, bullets: Int = 0) {
        storedWood += wood
        storedBullets += bullets
    }
    
    func withdrawWood(_ amount: Int) -> Int {
        let actual = min(amount, storedWood)
        storedWood -= actual
        return actual
    }
    
    func withdrawBullets(_ amount: Int) -> Int {
        let actual = min(amount, storedBullets)
        storedBullets -= actual
        return actual
    }
    
    func getBuildingsInRange(gameState: GameState) -> [PlayerBuilding] {
        var buildings: [PlayerBuilding] = []
        for building in gameState.allPlayerBuildings {
            guard building !== self else { continue }
            if gridPosition.isWithinRadius(GameBalance.depotBuildRadius, of: building.gridPosition) {
                buildings.append(building)
            }
        }
        return buildings
    }
    
    func getBuildingWithHighestNeed(gameState: GameState) -> PlayerBuilding? {
        let inRange = getBuildingsInRange(gameState: gameState)
        return inRange.filter { $0.needsAnyResource }.max { $0.totalDeficit < $1.totalDeficit }
    }
    
    override func update(deltaTime: TimeInterval, gameState: GameState) {
        super.update(deltaTime: deltaTime, gameState: gameState)
        
        prioritizations = prioritizations.filter { p in
            if let time = p.timeRemaining {
                return time > 0
            }
            return true
        }
        
        for i in prioritizations.indices {
            if prioritizations[i].timeRemaining != nil {
                prioritizations[i].timeRemaining! -= deltaTime
            }
        }
        
        dispatchResources(gameState: gameState, deltaTime: deltaTime)
    }
    
    private var dispatchCooldown: TimeInterval = 0
    
    private func dispatchResources(gameState: GameState, deltaTime: TimeInterval) {
        dispatchCooldown -= deltaTime
        guard dispatchCooldown <= 0 else { return }
        dispatchCooldown = 0.5
        
        var targetBuilding: PlayerBuilding?
        
        if let prioritized = prioritizations.first {
            targetBuilding = prioritized.targetBuilding
        } else {
            targetBuilding = getBuildingWithHighestNeed(gameState: gameState)
        }
        
        guard let target = targetBuilding else { return }
        
        if target.needsSurvivors && heldSurvivors > 0 {
            if withdrawSurvivor() {
                let survivor = FreeSurvivor(at: gridPosition)
                survivor.destinationBuilding = target
                _ = survivor.setDestination(target.gridPosition, map: gameState.map)
                gameState.addFreeSurvivor(survivor)
            }
        }
        
        if target.needsWood && storedWood >= GameBalance.truckCapacity && heldSurvivors > 0 {
            let amount = min(GameBalance.truckCapacity, target.woodDeficit)
            if withdrawSurvivor() {
                let wood = withdrawWood(amount)
                let truck = Truck(at: gridPosition, sourceDepot: self)
                truck.carryingWood = wood
                truck.targetBuilding = target
                _ = truck.setDestination(target.gridPosition, map: gameState.map)
                gameState.addTruck(truck)
            }
        }
        
        if target.needsBullets && storedBullets >= GameBalance.truckCapacity && heldSurvivors > 0 {
            let amount = min(GameBalance.truckCapacity, target.bulletDeficit)
            if withdrawSurvivor() {
                let bullets = withdrawBullets(amount)
                let truck = Truck(at: gridPosition, sourceDepot: self)
                truck.carryingBullets = bullets
                truck.targetBuilding = target
                _ = truck.setDestination(target.gridPosition, map: gameState.map)
                gameState.addTruck(truck)
            }
        }
    }
    
    func addPrioritization(_ prioritization: DepotPrioritization) {
        prioritizations.append(prioritization)
        if prioritization.mode == .heavyPour {
            hasHeavyPour = true
        }
        updateLabel()
    }
    
    func removeLastPrioritization() {
        if let last = prioritizations.popLast() {
            if last.mode == .heavyPour {
                hasHeavyPour = prioritizations.contains { $0.mode == .heavyPour }
            }
        }
        updateLabel()
    }
    
    func removeAllPrioritizations() {
        prioritizations.removeAll()
        hasHeavyPour = false
        updateLabel()
    }
    
    override func retreat(gameState: GameState) {
        if storedWood > 0 || storedBullets > 0 {
            let dropped = gameState.map.dropResources(at: gridPosition, wood: storedWood, bullets: storedBullets)
            gameState.addDroppedResource(dropped)
        }
        
        for _ in 0..<heldSurvivors {
            let survivor = FreeSurvivor(at: gridPosition)
            if let nearestDepot = gameState.findNearestDepot(to: gridPosition, excluding: self) {
                survivor.destinationDepot = nearestDepot
                _ = survivor.setDestination(nearestDepot.gridPosition, map: gameState.map)
            }
            gameState.addFreeSurvivor(survivor)
        }
        
        heldSurvivors = 0
        storedWood = 0
        storedBullets = 0
    }
}

// MARK: - Workshop
class Workshop: PlayerBuilding {
    weak var targetBuilding: CityBuilding?
    var targetTileType: TileType?
    var collectedWood: Int = 0
    var collectedBullets: Int = 0
    var collectedSurvivors: Int = 0
    var dynamiteProgress: Int = 0
    var isFinished: Bool = false
    var isOnDynamite: Bool = false
    var linkedBridgeId: Int?
    
    private var collectionTimer: TimeInterval = 0
    private var noiseAccumulator: Int = 0
    private var truckSpawnAccumulator: TimeInterval = 0
    
    init() {
        super.init(type: .workshop)
        survivorQuota = 1
    }
    
    override func update(deltaTime: TimeInterval, gameState: GameState) {
        super.update(deltaTime: deltaTime, gameState: gameState)
        
        guard presentSurvivors > 0, !isFinished else { return }
        
        if isOnDynamite {
            updateDynamitePlacement(deltaTime: deltaTime, gameState: gameState)
            return
        }
        
        if targetTileType == .debris {
            updateDebrisClearing(deltaTime: deltaTime, gameState: gameState)
            return
        }
        
        if let target = targetBuilding {
            updateResourceCollection(from: target, deltaTime: deltaTime, gameState: gameState)
        }
        
        updateTruckSpawning(deltaTime: deltaTime, gameState: gameState)
    }
    
    private func updateDynamitePlacement(deltaTime: TimeInterval, gameState: GameState) {
        let rate = calculateCollectionRate()
        collectionTimer += deltaTime * rate
        
        if collectionTimer >= 1.0 {
            collectionTimer -= 1.0
            dynamiteProgress += 1
            noiseAccumulator += 1
            
            if noiseAccumulator >= GameBalance.workshopMediumNoiseThreshold {
                noiseAccumulator = 0
                gameState.createNoiseEvent(at: gridPosition, level: .medium)
            }
            
            if dynamiteProgress >= GameBalance.dynamiteCharges {
                if let bridgeId = linkedBridgeId {
                    gameState.destroyBridge(id: bridgeId)
                    gameState.createNoiseEvent(at: gridPosition, level: .high)
                }
                finishWorkshop(gameState: gameState)
            }
        }
    }
    
    private func updateDebrisClearing(deltaTime: TimeInterval, gameState: GameState) {
        let rate = calculateCollectionRate()
        collectionTimer += deltaTime * rate
        
        if collectionTimer >= 1.0 {
            collectionTimer -= 1.0
            collectedWood += 1
            noiseAccumulator += 1
            
            if noiseAccumulator >= GameBalance.workshopMediumNoiseThreshold {
                noiseAccumulator = 0
                gameState.createNoiseEvent(at: gridPosition, level: .medium)
            }
        }
        
        if collectedWood >= 20 {
            gameState.map.setTile(at: gridPosition, type: .ground)
            gameState.scene?.refreshTerrain()
            finishWorkshop(gameState: gameState)
        }
    }
    
    private func updateResourceCollection(from building: CityBuilding, deltaTime: TimeInterval, gameState: GameState) {
        guard building.canBeHarvested else {
            if !building.hasResources && !building.hasZombies {
                finishWorkshop(gameState: gameState)
            }
            return
        }
        
        let rate = calculateCollectionRate()
        collectionTimer += deltaTime * rate
        
        if collectionTimer >= 1.0 {
            collectionTimer -= 1.0
            collectResource(from: building, gameState: gameState)
        }
    }
    
    private func calculateCollectionRate() -> Double {
        let baseRate: Double = 1.0
        return baseRate * pow(1.35, Double(presentSurvivors - 1))
    }
    
    private func collectResource(from building: CityBuilding, gameState: GameState) {
        let collectWood = building.resources.wood >= building.resources.bullets
        
        if collectWood && building.resources.wood > 0 {
            building.resources.wood -= 1
            collectedWood += 1
        } else if building.resources.bullets > 0 {
            building.resources.bullets -= 1
            collectedBullets += 1
        } else if building.resources.survivors > 0 {
            building.resources.survivors -= 1
            collectedSurvivors += 1
        }
        
        noiseAccumulator += 1
        
        if noiseAccumulator >= GameBalance.workshopMediumNoiseThreshold {
            noiseAccumulator = 0
            gameState.createNoiseEvent(at: gridPosition, level: .medium)
        }
    }
    
    private func updateTruckSpawning(deltaTime: TimeInterval, gameState: GameState) {
        truckSpawnAccumulator += deltaTime
        let spawnInterval = 1.0 / Double(GameBalance.workshopMaxTrucksPerSecond)
        
        while truckSpawnAccumulator >= spawnInterval {
            truckSpawnAccumulator -= spawnInterval
            
            if collectedWood >= GameBalance.truckCapacity && presentSurvivors > 1 {
                spawnTruck(wood: GameBalance.truckCapacity, bullets: 0, gameState: gameState)
                collectedWood -= GameBalance.truckCapacity
            } else if collectedBullets >= GameBalance.truckCapacity && presentSurvivors > 1 {
                spawnTruck(wood: 0, bullets: GameBalance.truckCapacity, gameState: gameState)
                collectedBullets -= GameBalance.truckCapacity
            } else if presentSurvivors == 1 && (collectedWood >= GameBalance.truckCapacity || collectedBullets >= GameBalance.truckCapacity) {
                if collectedWood >= GameBalance.truckCapacity {
                    spawnTruck(wood: GameBalance.truckCapacity, bullets: 0, gameState: gameState, returnToWorkshop: true)
                    collectedWood -= GameBalance.truckCapacity
                } else {
                    spawnTruck(wood: 0, bullets: GameBalance.truckCapacity, gameState: gameState, returnToWorkshop: true)
                    collectedBullets -= GameBalance.truckCapacity
                }
            } else if collectedSurvivors > 0 {
                if let depot = sourceDepot {
                    let survivor = FreeSurvivor(at: gridPosition)
                    survivor.destinationDepot = depot
                    _ = survivor.setDestination(depot.gridPosition, map: gameState.map)
                    gameState.addFreeSurvivor(survivor)
                    collectedSurvivors -= 1
                }
            } else {
                break
            }
        }
    }
    
    private func spawnTruck(wood: Int, bullets: Int, gameState: GameState, returnToWorkshop: Bool = false) {
        guard let depot = sourceDepot else { return }
        
        presentSurvivors -= 1
        
        let truck = Truck(at: gridPosition, sourceDepot: depot)
        truck.carryingWood = wood
        truck.carryingBullets = bullets
        truck.targetBuilding = depot
        truck.returnWorkshop = returnToWorkshop ? self : nil
        _ = truck.setDestination(depot.gridPosition, map: gameState.map)
        gameState.addTruck(truck)
    }
    
    private func finishWorkshop(gameState: GameState) {
        isFinished = true
        
        while collectedWood > 0 || collectedBullets > 0 {
            if collectedWood > 0 && presentSurvivors > 0 {
                let amount = min(GameBalance.truckCapacity, collectedWood)
                spawnTruck(wood: amount, bullets: 0, gameState: gameState)
                collectedWood -= amount
            } else if collectedBullets > 0 && presentSurvivors > 0 {
                let amount = min(GameBalance.truckCapacity, collectedBullets)
                spawnTruck(wood: 0, bullets: amount, gameState: gameState)
                collectedBullets -= amount
            } else {
                break
            }
        }
        
        for _ in 0..<presentSurvivors {
            if let depot = sourceDepot {
                let survivor = FreeSurvivor(at: gridPosition)
                survivor.destinationDepot = depot
                _ = survivor.setDestination(depot.gridPosition, map: gameState.map)
                gameState.addFreeSurvivor(survivor)
            }
        }
        presentSurvivors = 0
        
        gameState.removeWorkshop(self)
    }
    
    override func retreat(gameState: GameState) {
        finishWorkshop(gameState: gameState)
    }
    
    func onZombieAttack(zombieCount: Int, gameState: GameState) {
        var survivorsKilled = 0
        for _ in 0..<zombieCount {
            if CGFloat.random(in: 0...1) < GameBalance.workshopSurvivorDeathChance && presentSurvivors > survivorsKilled {
                survivorsKilled += 1
            }
        }
        
        for _ in 0..<survivorsKilled {
            presentSurvivors -= 1
            gameState.spawnZombie(at: gridPosition, type: .normal)
        }
        
        for _ in 0..<presentSurvivors {
            let scatterX = gridPosition.x + Int.random(in: -1...1)
            let scatterY = gridPosition.y + Int.random(in: -1...1)
            let scatterPos = GridPosition(x: scatterX, y: scatterY)
            
            let survivor = FreeSurvivor(at: scatterPos)
            if let depot = sourceDepot {
                survivor.destinationDepot = depot
                _ = survivor.setDestination(depot.gridPosition, map: gameState.map)
            }
            gameState.addFreeSurvivor(survivor)
        }
        presentSurvivors = 0
    }
}

// MARK: - Sniper Tower
class SniperTower: PlayerBuilding {
    var isHoldingFire: Bool = false
    private var fireTimer: TimeInterval = 0
    
    init() {
        super.init(type: .sniperTower)
        survivorQuota = 1
        bulletQuota = 50
    }
    
    var accuracy: CGFloat {
        let x = CGFloat(min(presentSurvivors, GameBalance.sniperMaxSurvivors))
        return x / CGFloat(GameBalance.sniperMaxSurvivors)
    }
    
    var canFire: Bool {
        return presentBullets > 0 && !isHoldingFire && presentSurvivors > 0
    }
    
    override func update(deltaTime: TimeInterval, gameState: GameState) {
        super.update(deltaTime: deltaTime, gameState: gameState)
        
        guard canFire else { return }
        
        fireTimer += deltaTime
        
        if fireTimer >= GameBalance.sniperFireRate {
            fireTimer = 0
            attemptShot(gameState: gameState)
        }
    }
    
    private func attemptShot(gameState: GameState) {
        guard let target = findTarget(gameState: gameState) else { return }
        
        presentBullets -= 1
        
        gameState.createNoiseEvent(at: gridPosition, level: .high)
        
        let roll = CGFloat.random(in: 0...1)
        let hit = roll <= accuracy
        
        if hit {
            gameState.killZombie(target)
        }
        
        if let scene = node?.scene as? GameScene {
            let from = gridPosition.toScenePosition()
            let to = target.node?.position ?? from
            scene.showSniperShot(from: from, to: to, hit: hit)
        }
    }
    
    private func findTarget(gameState: GameState) -> Zombie? {
        let towerPos = gridPosition.toScenePosition()
        let rangeInPoints = CGFloat(GameBalance.sniperRange) * GridConfig.tileSize
        
        var closestZombie: Zombie?
        var closestDistance: CGFloat = .infinity
        
        for zombie in gameState.zombies where !zombie.isDead {
            guard let zombieNode = zombie.node else { continue }
            let distance = towerPos.distance(to: zombieNode.position)
            
            if distance <= rangeInPoints && distance < closestDistance {
                closestDistance = distance
                closestZombie = zombie
            }
        }
        
        return closestZombie
    }
    
    func shootInAir(gameState: GameState) {
        guard presentBullets > 0 else { return }
        
        presentBullets -= 1
        gameState.createNoiseEvent(at: gridPosition, level: .high)
        
        if let scene = node?.scene as? GameScene {
            let from = gridPosition.toScenePosition()
            let to = CGPoint(x: from.x, y: from.y + 100)
            scene.showSniperShot(from: from, to: to, hit: false)
        }
    }
    
    override func retreat(gameState: GameState) {
        if presentWood > 0 || presentBullets > 0 {
            let dropped = gameState.map.dropResources(at: gridPosition, wood: presentWood, bullets: presentBullets)
            gameState.addDroppedResource(dropped)
        }
        
        for _ in 0..<presentSurvivors {
            if let depot = sourceDepot ?? gameState.findNearestDepot(to: gridPosition, excluding: nil) {
                let survivor = FreeSurvivor(at: gridPosition)
                survivor.destinationDepot = depot
                _ = survivor.setDestination(depot.gridPosition, map: gameState.map)
                gameState.addFreeSurvivor(survivor)
            }
        }
        
        presentSurvivors = 0
        presentBullets = 0
        presentWood = 0
    }
}

// MARK: - Barricade
class Barricade: PlayerBuilding {
    init() {
        super.init(type: .barricade)
    }
    
    var health: Int { presentWood }
    override var isDestroyed: Bool { presentWood <= 0 && woodQuota <= 0 }
    
    func takeDamage(_ amount: Int) {
        presentWood = max(0, presentWood - amount)
        updateVisual()
    }
    
    private func updateVisual() {
        guard let shapeNode = node as? SKShapeNode else { return }
        
        let maxHealth = max(woodQuota, 1)
        let healthPercent = CGFloat(presentWood) / CGFloat(maxHealth)
        
        let red = 0.7 + (1.0 - healthPercent) * 0.3
        let green = 0.5 * healthPercent
        let blue = 0.3 * healthPercent
        
        shapeNode.fillColor = SKColor(red: red, green: green, blue: blue, alpha: 1.0)
    }
    
    override func retreat(gameState: GameState) {
        woodQuota = 0
    }
}
