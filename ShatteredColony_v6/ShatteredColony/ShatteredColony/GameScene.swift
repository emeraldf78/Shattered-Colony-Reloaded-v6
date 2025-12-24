import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    // MARK: - Layers
    var gameLayer: SKNode!
    var terrainLayer: SKNode!
    var aoeLayer: SKNode!
    var uiLayer: SKNode!
    
    // MARK: - Game State
    var gameState: GameState!
    
    // MARK: - Camera
    var cameraNode: SKCameraNode!
    
    // MARK: - UI Elements
    var pauseButton: SKShapeNode!
    var speedButton: SKShapeNode!
    var menuButton: SKShapeNode!
    var timerLabel: SKLabelNode!
    var resourceLabel: SKLabelNode!
    var buildingButtons: [SKNode] = []
    var multiBuildToggle: SKShapeNode!
    var showSniperAoeToggle: SKShapeNode!
    var showConnectionsToggle: SKShapeNode!
    
    // MARK: - Build Mode
    var selectedBuildingType: PlayerBuildingType?
    var isMultiBuildEnabled: Bool = false
    var isDraggingPlacement: Bool = false
    var placementPreview: SKNode?
    var placementAoePreview: SKNode?
    
    // MARK: - Building Selection
    var selectedBuilding: PlayerBuilding?
    var buildingMenuPanel: SKNode?
    
    // MARK: - Overlays
    var sniperAoeOverlay: SKNode?
    var connectionLinesNode: SKNode?
    var showAllConnections: Bool = false
    var showAllSniperAoe: Bool = false
    
    // MARK: - Pause Menu
    var pauseMenuOverlay: SKNode?
    var isPauseMenuOpen: Bool = false
    
    // MARK: - Free Depot Placement
    var needsFreeDepot: Bool = false
    var freeDepotPopup: SKNode?
    
    // MARK: - Lifecycle
    
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        
        setupLayers()
        setupCamera()
        setupGame()
        setupUI()
        setupGestures()
        
        checkForFreeDepot()
    }
    
    private func setupLayers() {
        gameLayer = SKNode()
        gameLayer.zPosition = 0
        addChild(gameLayer)
        
        terrainLayer = SKNode()
        terrainLayer.zPosition = ZPosition.terrain
        gameLayer.addChild(terrainLayer)
        
        aoeLayer = SKNode()
        aoeLayer.zPosition = ZPosition.areaOfEffect
        gameLayer.addChild(aoeLayer)
        
        uiLayer = SKNode()
        uiLayer.zPosition = ZPosition.ui
        addChild(uiLayer)
    }
    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
        
        let mapWidth = CGFloat(GridConfig.mapWidth) * GridConfig.tileSize
        let mapHeight = CGFloat(GridConfig.mapHeight) * GridConfig.tileSize
        cameraNode.position = CGPoint(x: mapWidth / 2, y: mapHeight / 2)
        
        let scaleX = size.width / mapWidth
        let scaleY = size.height / (mapHeight + 80)
        let scale = min(scaleX, scaleY) * 0.85
        cameraNode.setScale(1.0 / scale)
    }
    
    private func setupGame() {
        let map = createTestLevel()
        gameState = GameState(map: map)
        gameState.scene = self
        
        renderTerrain()
        renderCityBuildings()
        setupInitialState()
    }
    
    // MARK: - Check for Free Depot
    
    private func checkForFreeDepot() {
        if gameState.depots.isEmpty {
            needsFreeDepot = true
            gameState.timeSpeed = .paused
            showFreeDepotPopup()
        }
    }
    
    private func showFreeDepotPopup() {
        let popup = SKShapeNode(rectOf: CGSize(width: 320, height: 120), cornerRadius: 15)
        popup.fillColor = SKColor(red: 0.1, green: 0.2, blue: 0.1, alpha: 0.95)
        popup.strokeColor = .green
        popup.lineWidth = 3
        popup.position = .zero
        popup.zPosition = ZPosition.popup
        
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.text = "Let's get started!"
        title.fontSize = 20
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 25)
        popup.addChild(title)
        
        let subtitle = SKLabelNode(fontNamed: "Helvetica")
        subtitle.text = "Place a free depot on the map."
        subtitle.fontSize = 14
        subtitle.fontColor = .lightGray
        subtitle.position = CGPoint(x: 0, y: -5)
        popup.addChild(subtitle)
        
        let hint = SKLabelNode(fontNamed: "Helvetica")
        hint.text = "Tap anywhere on the ground to place."
        hint.fontSize = 12
        hint.fontColor = .gray
        hint.position = CGPoint(x: 0, y: -30)
        popup.addChild(hint)
        
        cameraNode.addChild(popup)
        freeDepotPopup = popup
        
        // Auto-select depot for placement
        selectedBuildingType = .depot
    }
    
    private func placeFreeDepot(at position: GridPosition) {
        let depot = Depot()
        depot.heldSurvivors = GameBalance.freeDepotSurvivors
        depot.storedWood = GameBalance.freeDepotWood
        depot.storedBullets = GameBalance.freeDepotBullets
        
        if gameState.addDepot(depot, at: position) {
            needsFreeDepot = false
            freeDepotPopup?.removeFromParent()
            freeDepotPopup = nil
            selectedBuildingType = nil
            gameState.timeSpeed = .normal
        }
    }
    
    // MARK: - Test Level Creation
    
    private func createTestLevel() -> GameMap {
        let map = GameMap()
        
        // Water with bridges
        for x in 0..<map.width {
            map.setTile(at: GridPosition(x: x, y: 58), type: .water)
            map.setTile(at: GridPosition(x: x, y: 59), type: .water)
        }
        map.addBridge(from: GridPosition(x: 30, y: 58), to: GridPosition(x: 33, y: 59))
        
        for x in 0..<map.width {
            map.setTile(at: GridPosition(x: x, y: 4), type: .water)
            map.setTile(at: GridPosition(x: x, y: 5), type: .water)
        }
        map.addBridge(from: GridPosition(x: 30, y: 4), to: GridPosition(x: 33, y: 5))
        
        // Add some debris
        let debrisPositions = [
            GridPosition(x: 25, y: 30), GridPosition(x: 26, y: 30),
            GridPosition(x: 38, y: 32), GridPosition(x: 39, y: 32)
        ]
        for pos in debrisPositions {
            map.setTile(at: pos, type: .debris)
        }
        
        // NE buildings - safe with resources
        let nePositions = [
            GridPosition(x: 45, y: 45), GridPosition(x: 50, y: 45),
            GridPosition(x: 45, y: 50), GridPosition(x: 50, y: 50),
            GridPosition(x: 55, y: 45), GridPosition(x: 55, y: 50),
            GridPosition(x: 45, y: 38), GridPosition(x: 50, y: 38)
        ]
        
        for pos in nePositions {
            let resources = Resources(
                wood: Int.random(in: 1...40),
                bullets: Int.random(in: 1...40),
                survivors: Int.random(in: 1...40)
            )
            map.addCityBuilding(at: pos, doorSide: .south, zombieCount: 0, resources: resources)
        }
        
        // SW buildings - zombies
        let swPositions = [
            GridPosition(x: 8, y: 10), GridPosition(x: 8, y: 15),
            GridPosition(x: 8, y: 20), GridPosition(x: 8, y: 25),
            GridPosition(x: 14, y: 10), GridPosition(x: 14, y: 15),
            GridPosition(x: 14, y: 20), GridPosition(x: 14, y: 25)
        ]
        
        for pos in swPositions {
            let zombieCount = Int.random(in: 1...3)
            let resources = Resources(
                wood: Int.random(in: 10...30),
                bullets: Int.random(in: 10...30),
                survivors: Int.random(in: 0...5)
            )
            map.addCityBuilding(at: pos, doorSide: .east, zombieCount: zombieCount, resources: resources)
        }
        
        // NW max zombies
        map.addCityBuilding(
            at: GridPosition(x: 10, y: 50),
            doorSide: .south,
            zombieCount: 3,
            resources: Resources(wood: 50, bullets: 50, survivors: 10)
        )
        
        return map
    }
    
    private func setupInitialState() {
        let centerX = GridConfig.mapWidth / 2
        let centerY = GridConfig.mapHeight / 2
        
        // Main depot
        let mainDepot = Depot()
        mainDepot.storedWood = 100
        mainDepot.storedBullets = 500
        mainDepot.heldSurvivors = 24
        _ = gameState.addDepot(mainDepot, at: GridPosition(x: centerX - 1, y: centerY - 1))
        
        // Snipers
        let leftSniper = SniperTower()
        leftSniper.presentBullets = 50
        leftSniper.presentSurvivors = 5
        _ = gameState.addSniperTower(leftSniper, at: GridPosition(x: centerX - 5, y: centerY))
        
        let rightSniper = SniperTower()
        rightSniper.presentBullets = 50
        rightSniper.presentSurvivors = 5
        _ = gameState.addSniperTower(rightSniper, at: GridPosition(x: centerX + 4, y: centerY))
        
        // SE zombies
        let sePositions = [
            GridPosition(x: 50, y: 15), GridPosition(x: 52, y: 17),
            GridPosition(x: 54, y: 15), GridPosition(x: 56, y: 17),
            GridPosition(x: 50, y: 20), GridPosition(x: 52, y: 22),
            GridPosition(x: 54, y: 20), GridPosition(x: 56, y: 22)
        ]
        
        for pos in sePositions {
            gameState.spawnZombie(at: pos, type: .normal)
        }
    }
    
    // MARK: - Rendering
    
    private func renderTerrain() {
        terrainLayer.removeAllChildren()
        
        for y in 0..<gameState.map.height {
            for x in 0..<gameState.map.width {
                let pos = GridPosition(x: x, y: y)
                if let tile = gameState.map.tile(at: pos) {
                    let tileNode = SKShapeNode(rectOf: CGSize(
                        width: GridConfig.tileSize - 0.5,
                        height: GridConfig.tileSize - 0.5
                    ))
                    tileNode.fillColor = tile.type.color
                    tileNode.strokeColor = .clear
                    tileNode.position = pos.toScenePosition()
                    tileNode.zPosition = ZPosition.terrain
                    terrainLayer.addChild(tileNode)
                }
            }
        }
    }
    
    private func renderCityBuildings() {
        for building in gameState.map.cityBuildings {
            let width = CGFloat(2) * GridConfig.tileSize
            let height = CGFloat(3) * GridConfig.tileSize
            
            let node = SKShapeNode(rectOf: CGSize(width: width - 2, height: height - 2))
            node.fillColor = building.zombieLevel.color
            node.strokeColor = SKColor(white: 0.2, alpha: 1.0)
            node.lineWidth = 1
            
            let centerX = CGFloat(building.buildingOrigin.x) * GridConfig.tileSize + width / 2
            let centerY = CGFloat(building.buildingOrigin.y) * GridConfig.tileSize + height / 2
            node.position = CGPoint(x: centerX, y: centerY)
            node.zPosition = ZPosition.cityBuildings
            
            building.node = node
            gameLayer.addChild(node)
            
            // Door
            let door = SKShapeNode(rectOf: CGSize(width: GridConfig.tileSize - 4, height: GridConfig.tileSize - 4))
            door.fillColor = SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            door.strokeColor = SKColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 1.0)
            door.lineWidth = 1
            door.position = building.doorPosition.toScenePosition()
            door.zPosition = ZPosition.cityBuildings + 1
            gameLayer.addChild(door)
        }
    }
    
    func refreshTerrain() {
        renderTerrain()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Pause button
        pauseButton = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 5)
        pauseButton.fillColor = SKColor.darkGray
        pauseButton.strokeColor = .white
        pauseButton.position = CGPoint(x: -size.width/2 + 30, y: size.height/2 - 30)
        pauseButton.zPosition = ZPosition.ui
        pauseButton.name = "pauseButton"
        
        let pauseLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        pauseLabel.fontSize = 20
        pauseLabel.text = "⏸"
        pauseLabel.verticalAlignmentMode = .center
        pauseButton.addChild(pauseLabel)
        cameraNode.addChild(pauseButton)
        
        // Speed button
        speedButton = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 5)
        speedButton.fillColor = SKColor.darkGray
        speedButton.strokeColor = .white
        speedButton.position = CGPoint(x: -size.width/2 + 80, y: size.height/2 - 30)
        speedButton.zPosition = ZPosition.ui
        speedButton.name = "speedButton"
        
        let speedLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        speedLabel.fontSize = 14
        speedLabel.text = "1x"
        speedLabel.verticalAlignmentMode = .center
        speedLabel.name = "speedLabel"
        speedButton.addChild(speedLabel)
        cameraNode.addChild(speedButton)
        
        // Menu button
        menuButton = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 5)
        menuButton.fillColor = SKColor.darkGray
        menuButton.strokeColor = .white
        menuButton.position = CGPoint(x: size.width/2 - 30, y: size.height/2 - 30)
        menuButton.zPosition = ZPosition.ui
        menuButton.name = "menuButton"
        
        let menuLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        menuLabel.fontSize = 20
        menuLabel.text = "☰"
        menuLabel.verticalAlignmentMode = .center
        menuButton.addChild(menuLabel)
        cameraNode.addChild(menuButton)
        
        // Timer
        timerLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        timerLabel.fontSize = 24
        timerLabel.fontColor = .white
        timerLabel.position = CGPoint(x: 0, y: size.height/2 - 35)
        timerLabel.zPosition = ZPosition.ui
        cameraNode.addChild(timerLabel)
        
        let timerBg = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 5)
        timerBg.fillColor = SKColor.black.withAlphaComponent(0.7)
        timerBg.strokeColor = .red
        timerBg.lineWidth = 2
        timerBg.position = CGPoint(x: 0, y: size.height/2 - 30)
        timerBg.zPosition = ZPosition.uiBackground
        cameraNode.addChild(timerBg)
        
        // Resources
        resourceLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        resourceLabel.fontSize = 14
        resourceLabel.fontColor = .white
        resourceLabel.horizontalAlignmentMode = .right
        resourceLabel.position = CGPoint(x: size.width/2 - 60, y: size.height/2 - 35)
        resourceLabel.zPosition = ZPosition.ui
        cameraNode.addChild(resourceLabel)
        
        setupBuildingButtons()
        updateUI()
    }
    
    private func setupBuildingButtons() {
        let buttonSize: CGFloat = 40
        let spacing: CGFloat = 6
        let types = PlayerBuildingType.allCases
        let startX: CGFloat = -size.width/2 + 30
        let bottomY: CGFloat = -size.height/2 + buttonSize/2 + 15
        
        for (index, type) in types.enumerated() {
            let button = SKShapeNode(rectOf: CGSize(width: buttonSize, height: buttonSize), cornerRadius: 5)
            button.fillColor = type.color
            button.strokeColor = .white
            button.lineWidth = 2
            button.position = CGPoint(x: startX + CGFloat(index) * (buttonSize + spacing), y: bottomY)
            button.zPosition = ZPosition.ui
            button.name = "buildButton_\(index)"
            
            let label = SKLabelNode(fontNamed: "Helvetica")
            label.fontSize = 7
            label.fontColor = .white
            label.numberOfLines = 2
            label.verticalAlignmentMode = .center
            
            switch type {
            case .workshop: label.text = "WORK"
            case .depot: label.text = "DEPOT"
            case .sniperTower: label.text = "SNIPE"
            case .barricade: label.text = "WALL"
            }
            
            button.addChild(label)
            cameraNode.addChild(button)
            buildingButtons.append(button)
        }
        
        // Multi-build toggle
        let toggleX = startX + CGFloat(types.count) * (buttonSize + spacing) + 20
        multiBuildToggle = SKShapeNode(rectOf: CGSize(width: 50, height: buttonSize), cornerRadius: 5)
        multiBuildToggle.fillColor = .darkGray
        multiBuildToggle.strokeColor = .gray
        multiBuildToggle.lineWidth = 1
        multiBuildToggle.position = CGPoint(x: toggleX, y: bottomY)
        multiBuildToggle.zPosition = ZPosition.ui
        multiBuildToggle.name = "multiBuildToggle"
        
        let multiLabel = SKLabelNode(fontNamed: "Helvetica")
        multiLabel.fontSize = 8
        multiLabel.text = "MULTI"
        multiLabel.fontColor = .white
        multiLabel.verticalAlignmentMode = .center
        multiBuildToggle.addChild(multiLabel)
        cameraNode.addChild(multiBuildToggle)
        
        // Sniper AOE toggle
        showSniperAoeToggle = SKShapeNode(rectOf: CGSize(width: 50, height: buttonSize), cornerRadius: 5)
        showSniperAoeToggle.fillColor = .darkGray
        showSniperAoeToggle.strokeColor = .gray
        showSniperAoeToggle.lineWidth = 1
        showSniperAoeToggle.position = CGPoint(x: toggleX + 56, y: bottomY)
        showSniperAoeToggle.zPosition = ZPosition.ui
        showSniperAoeToggle.name = "sniperAoeToggle"
        
        let aoeLabel = SKLabelNode(fontNamed: "Helvetica")
        aoeLabel.fontSize = 8
        aoeLabel.text = "AOE"
        aoeLabel.fontColor = .white
        aoeLabel.verticalAlignmentMode = .center
        showSniperAoeToggle.addChild(aoeLabel)
        cameraNode.addChild(showSniperAoeToggle)
        
        // Connections toggle
        showConnectionsToggle = SKShapeNode(rectOf: CGSize(width: 50, height: buttonSize), cornerRadius: 5)
        showConnectionsToggle.fillColor = .darkGray
        showConnectionsToggle.strokeColor = .gray
        showConnectionsToggle.lineWidth = 1
        showConnectionsToggle.position = CGPoint(x: toggleX + 112, y: bottomY)
        showConnectionsToggle.zPosition = ZPosition.ui
        showConnectionsToggle.name = "connectionsToggle"
        
        let connLabel = SKLabelNode(fontNamed: "Helvetica")
        connLabel.fontSize = 8
        connLabel.text = "CONN"
        connLabel.fontColor = .white
        connLabel.verticalAlignmentMode = .center
        showConnectionsToggle.addChild(connLabel)
        cameraNode.addChild(showConnectionsToggle)
    }
    
    private func updateUI() {
        // Timer
        let minutes = Int(gameState.roundTimer) / 60
        let seconds = Int(gameState.roundTimer) % 60
        timerLabel.text = String(format: "%d:%02d", minutes, seconds)
        timerLabel.fontColor = gameState.roundTimer < 30 ? .red : .white
        
        // Resources
        if let depot = gameState.depots.first {
            resourceLabel.text = "🪵\(depot.storedWood) 🔫\(depot.storedBullets) 👤\(depot.heldSurvivors)"
        }
        
        // Speed label
        if let speedLabel = speedButton.childNode(withName: "speedLabel") as? SKLabelNode {
            speedLabel.text = gameState.timeSpeed.displayName
        }
        
        // Pause button
        if let pauseLabel = pauseButton.children.first as? SKLabelNode {
            pauseLabel.text = gameState.timeSpeed == .paused ? "▶️" : "⏸"
        }
        
        // Multi-build toggle
        multiBuildToggle.fillColor = isMultiBuildEnabled ? .green : .darkGray
        multiBuildToggle.strokeColor = isMultiBuildEnabled ? .white : .gray
        
        // AOE toggle
        showSniperAoeToggle.fillColor = showAllSniperAoe ? .purple : .darkGray
        showSniperAoeToggle.strokeColor = showAllSniperAoe ? .white : .gray
        
        // Connections toggle
        showConnectionsToggle.fillColor = showAllConnections ? .blue : .darkGray
        showConnectionsToggle.strokeColor = showAllConnections ? .white : .gray
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view?.addGestureRecognizer(pinch)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        view?.addGestureRecognizer(pan)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let newScale = cameraNode.xScale / gesture.scale
            let clampedScale = max(0.3, min(4.0, newScale))
            cameraNode.setScale(clampedScale)
            gesture.scale = 1.0
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let scale = cameraNode.xScale
        
        cameraNode.position.x -= translation.x * scale
        cameraNode.position.y += translation.y * scale
        
        gesture.setTranslation(.zero, in: view)
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let uiLocation = touch.location(in: cameraNode)
        let gameLocation = touch.location(in: gameLayer)
        let gridPos = GridPosition.fromScenePosition(gameLocation)
        
        // Check UI buttons first
        if handleUITouch(at: uiLocation) { return }
        
        // Free depot placement
        if needsFreeDepot {
            if gameState.map.canPlacePlayerBuilding(type: .depot, at: gridPos, depots: []) {
                placeFreeDepot(at: gridPos)
            }
            return
        }
        
        // Building placement mode
        if selectedBuildingType != nil {
            isDraggingPlacement = true
            updatePlacementPreview(at: gridPos)
            return
        }
        
        // Select building
        handleBuildingSelection(at: gridPos)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, isDraggingPlacement else { return }
        
        let gameLocation = touch.location(in: gameLayer)
        let gridPos = GridPosition.fromScenePosition(gameLocation)
        updatePlacementPreview(at: gridPos)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        if isDraggingPlacement {
            isDraggingPlacement = false
            let gameLocation = touch.location(in: gameLayer)
            let gridPos = GridPosition.fromScenePosition(gameLocation)
            attemptPlaceBuilding(at: gridPos)
        }
    }
    
    private func handleUITouch(at location: CGPoint) -> Bool {
        // Menu button
        if menuButton.contains(location) {
            togglePauseMenu()
            return true
        }
        
        // Pause menu
        if isPauseMenuOpen {
            handlePauseMenuTouch(at: location)
            return true
        }
        
        // Pause button
        if pauseButton.contains(location) {
            togglePause()
            return true
        }
        
        // Speed button
        if speedButton.contains(location) {
            cycleSpeed()
            return true
        }
        
        // Multi-build toggle
        if multiBuildToggle.contains(location) {
            isMultiBuildEnabled = !isMultiBuildEnabled
            updateUI()
            return true
        }
        
        // Sniper AOE toggle
        if showSniperAoeToggle.contains(location) {
            showAllSniperAoe = !showAllSniperAoe
            updateSniperAoeOverlay()
            updateUI()
            return true
        }
        
        // Connections toggle
        if showConnectionsToggle.contains(location) {
            showAllConnections = !showAllConnections
            updateConnectionLines()
            updateUI()
            return true
        }
        
        // Building buttons
        for (index, button) in buildingButtons.enumerated() {
            if button.contains(location) {
                let type = PlayerBuildingType.allCases[index]
                if selectedBuildingType == type {
                    // Clicking same button deselects
                    selectedBuildingType = nil
                    clearPlacementPreview()
                } else {
                    selectedBuildingType = type
                }
                highlightBuildButton(index: selectedBuildingType == type ? index : -1)
                return true
            }
        }
        
        // Building menu panel
        if let panel = buildingMenuPanel, panel.contains(location) {
            handleBuildingMenuTouch(at: location)
            return true
        }
        
        return false
    }
    
    // MARK: - Placement Preview
    
    private func updatePlacementPreview(at position: GridPosition) {
        guard let buildType = selectedBuildingType else { return }
        
        clearPlacementPreview()
        
        // Create preview node
        let preview = SKShapeNode(rectOf: buildType.size)
        preview.strokeColor = .white
        preview.lineWidth = 2
        preview.position = position.toScenePosition()
        preview.zPosition = ZPosition.playerBuildings + 5
        
        // Check placement validity
        let error = validatePlacement(type: buildType, at: position)
        
        if error == .none {
            preview.fillColor = buildType.color.withAlphaComponent(0.6)
        } else {
            preview.fillColor = SKColor.red.withAlphaComponent(0.5)
        }
        
        gameLayer.addChild(preview)
        placementPreview = preview
        
        // Show AOE preview
        if buildType.hasAreaOfEffect {
            showAoePreview(at: position, radius: buildType.areaOfEffectRadius, isValid: error == .none)
        }
    }
    
    private func showAoePreview(at position: GridPosition, radius: Int, isValid: Bool) {
        let aoePreview = SKShapeNode(circleOfRadius: CGFloat(radius) * GridConfig.tileSize)
        aoePreview.fillColor = isValid ? 
            SKColor.gray.withAlphaComponent(0.2) : 
            SKColor.red.withAlphaComponent(0.2)
        aoePreview.strokeColor = isValid ? .gray : .red
        aoePreview.lineWidth = 1
        aoePreview.position = position.toScenePosition()
        aoePreview.zPosition = ZPosition.areaOfEffect
        
        aoeLayer.addChild(aoePreview)
        placementAoePreview = aoePreview
        
        // Highlight buildings in range
        highlightBuildingsInRange(of: position, radius: radius, color: isValid ? .green : .red)
    }
    
    private func highlightBuildingsInRange(of position: GridPosition, radius: Int, color: SKColor) {
        for building in gameState.allPlayerBuildings {
            if position.isWithinRadius(radius, of: building.gridPosition) {
                if let shapeNode = building.node as? SKShapeNode {
                    shapeNode.strokeColor = color.withAlphaComponent(0.8)
                    shapeNode.lineWidth = 3
                }
            }
        }
    }
    
    private func clearPlacementPreview() {
        placementPreview?.removeFromParent()
        placementPreview = nil
        placementAoePreview?.removeFromParent()
        placementAoePreview = nil
        
        // Reset building highlights
        for building in gameState.allPlayerBuildings {
            if let shapeNode = building.node as? SKShapeNode {
                shapeNode.strokeColor = .white
                shapeNode.lineWidth = 1
            }
        }
    }
    
    private func validatePlacement(type: PlayerBuildingType, at position: GridPosition) -> PlacementError {
        guard let tile = gameState.map.tile(at: position) else {
            return .invalidLocation
        }
        
        // Workshop special cases
        if type == .workshop {
            if tile.type == .water || tile.type == .buildingWall {
                return .invalidLocation
            }
            if let cityBuilding = gameState.map.getCityBuildingWithDoor(at: position) {
                if cityBuilding.hasWorkshop {
                    return .alreadyHasWorkshop
                }
            } else if tile.type != .debris && tile.type != .dynamite {
                // Check for barricade
                if tile.playerBuilding as? Barricade == nil {
                    return .nothingToScavenge
                }
            }
        } else {
            if !tile.canPlaceBuilding {
                return .invalidLocation
            }
        }
        
        // Check depot range (except for depots)
        if type != .depot && !gameState.isWithinAnyDepotRadius(position) {
            return .outOfRange
        }
        
        return .none
    }
    
    private func attemptPlaceBuilding(at position: GridPosition) {
        guard let buildType = selectedBuildingType else { return }
        
        let error = validatePlacement(type: buildType, at: position)
        
        if error != .none {
            showPlacementError(error)
            clearPlacementPreview()
            return
        }
        
        var success = false
        
        switch buildType {
        case .depot:
            let depot = Depot()
            success = gameState.addDepot(depot, at: position)
            
        case .workshop:
            let workshop = Workshop()
            if let tile = gameState.map.tile(at: position) {
                if let cityBuilding = gameState.map.getCityBuildingWithDoor(at: position) {
                    success = gameState.addWorkshop(workshop, at: position, targetBuilding: cityBuilding)
                } else if tile.type == .debris {
                    workshop.targetTileType = .debris
                    success = gameState.addWorkshop(workshop, at: position, targetBuilding: nil)
                } else if tile.type == .dynamite {
                    workshop.isOnDynamite = true
                    workshop.linkedBridgeId = gameState.map.getDynamiteBridgeId(at: position)
                    success = gameState.addWorkshop(workshop, at: position, targetBuilding: nil)
                }
            }
            
        case .sniperTower:
            let sniper = SniperTower()
            success = gameState.addSniperTower(sniper, at: position)
            
        case .barricade:
            let barricade = Barricade()
            success = gameState.addBarricade(barricade, at: position)
        }
        
        clearPlacementPreview()
        
        if success {
            if !isMultiBuildEnabled {
                selectedBuildingType = nil
                highlightBuildButton(index: -1)
            }
        }
    }
    
    private func showPlacementError(_ error: PlacementError) {
        let errorLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        errorLabel.text = error.message
        errorLabel.fontSize = 18
        errorLabel.fontColor = .red
        errorLabel.position = CGPoint(x: 0, y: size.height/2 - 80)
        errorLabel.zPosition = ZPosition.popup
        errorLabel.alpha = 0
        
        cameraNode.addChild(errorLabel)
        
        let fadeIn = SKAction.fadeIn(withDuration: 0.2)
        let wait = SKAction.wait(forDuration: 1.5)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        
        errorLabel.run(SKAction.sequence([fadeIn, wait, fadeOut, remove]))
    }
    
    private func highlightBuildButton(index: Int) {
        for (i, button) in buildingButtons.enumerated() {
            if let shape = button as? SKShapeNode {
                shape.strokeColor = (i == index) ? .yellow : .white
                shape.lineWidth = (i == index) ? 3 : 2
            }
        }
    }
    
    // MARK: - Building Selection & Menu
    
    private func handleBuildingSelection(at position: GridPosition) {
        closeBuildingMenu()
        
        if let tile = gameState.map.tile(at: position),
           let building = tile.playerBuilding {
            selectedBuilding = building
            showBuildingMenu(for: building)
            showBuildingAoe(for: building)
        } else {
            selectedBuilding = nil
        }
    }
    
    private func showBuildingMenu(for building: PlayerBuilding) {
        let panelWidth: CGFloat = 180
        let panelHeight: CGFloat = 200
        
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 10)
        panel.fillColor = SKColor.black.withAlphaComponent(0.9)
        panel.strokeColor = building.type.color
        panel.lineWidth = 2
        panel.position = CGPoint(x: size.width/2 - panelWidth/2 - 10, y: -size.height/2 + panelHeight/2 + 60)
        panel.zPosition = ZPosition.ui + 10
        
        // Title
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.fontSize = 14
        title.fontColor = .white
        
        switch building.type {
        case .depot: title.text = "DEPOT"
        case .workshop: title.text = "WORKSHOP"
        case .sniperTower: title.text = "SNIPER TOWER"
        case .barricade: title.text = "BARRICADE"
        }
        
        title.position = CGPoint(x: 0, y: panelHeight/2 - 20)
        panel.addChild(title)
        
        // Add building-specific controls
        addBuildingControls(to: panel, for: building)
        
        cameraNode.addChild(panel)
        buildingMenuPanel = panel
    }
    
    private func addBuildingControls(to panel: SKNode, for building: PlayerBuilding) {
        var yPos: CGFloat = 50
        
        // Survivors
        let survivorLabel = SKLabelNode(fontNamed: "Helvetica")
        survivorLabel.fontSize = 11
        survivorLabel.text = "Survivors: \(building.presentSurvivors)/\(building.survivorQuota)"
        survivorLabel.position = CGPoint(x: 0, y: yPos)
        survivorLabel.fontColor = building.needsSurvivors ? .orange : .white
        panel.addChild(survivorLabel)
        
        // +/- buttons for survivors
        addPlusMinusButtons(to: panel, yPos: yPos - 15, tag: "survivor", increment: 1)
        
        yPos -= 45
        
        // Building-specific
        if let sniper = building as? SniperTower {
            let bulletLabel = SKLabelNode(fontNamed: "Helvetica")
            bulletLabel.fontSize = 11
            bulletLabel.text = "Bullets: \(sniper.presentBullets)/\(sniper.bulletQuota)"
            bulletLabel.position = CGPoint(x: 0, y: yPos)
            bulletLabel.fontColor = sniper.needsBullets ? .orange : .white
            panel.addChild(bulletLabel)
            
            addBulletButtons(to: panel, yPos: yPos - 15)
            
            yPos -= 45
            
            let accuracyLabel = SKLabelNode(fontNamed: "Helvetica")
            accuracyLabel.fontSize = 10
            accuracyLabel.text = "Accuracy: \(Int(sniper.accuracy * 100))%"
            accuracyLabel.position = CGPoint(x: 0, y: yPos)
            accuracyLabel.fontColor = .cyan
            panel.addChild(accuracyLabel)
            
            yPos -= 25
            
            // Action buttons
            addActionButton(to: panel, title: "Shoot Air", name: "shootAir", yPos: yPos, color: .orange)
            yPos -= 25
            addActionButton(to: panel, title: sniper.isHoldingFire ? "Resume Fire" : "Hold Fire", name: "holdFire", yPos: yPos, color: sniper.isHoldingFire ? .green : .red)
            
        } else if let barricade = building as? Barricade {
            let woodLabel = SKLabelNode(fontNamed: "Helvetica")
            woodLabel.fontSize = 11
            woodLabel.text = "Wood: \(barricade.presentWood)/\(barricade.woodQuota)"
            woodLabel.position = CGPoint(x: 0, y: yPos)
            woodLabel.fontColor = barricade.needsWood ? .orange : .white
            panel.addChild(woodLabel)
            
            addPlusMinusButtons(to: panel, yPos: yPos - 15, tag: "wood", increment: 10)
            
        } else if building is Depot {
            // Show dependencies button
            yPos -= 20
            addActionButton(to: panel, title: "✨ Dependencies", name: "dependencies", yPos: yPos, color: .cyan)
        }
        
        // Retreat button
        addActionButton(to: panel, title: "Retreat", name: "retreat", yPos: -70, color: .red)
    }
    
    private func addPlusMinusButtons(to panel: SKNode, yPos: CGFloat, tag: String, increment: Int) {
        let minusBtn = SKShapeNode(rectOf: CGSize(width: 30, height: 20), cornerRadius: 3)
        minusBtn.fillColor = .darkGray
        minusBtn.strokeColor = .white
        minusBtn.position = CGPoint(x: -50, y: yPos)
        minusBtn.name = "minus_\(tag)"
        let minusLabel = SKLabelNode(text: "-\(increment)")
        minusLabel.fontSize = 10
        minusLabel.fontColor = .white
        minusLabel.verticalAlignmentMode = .center
        minusBtn.addChild(minusLabel)
        panel.addChild(minusBtn)
        
        let plusBtn = SKShapeNode(rectOf: CGSize(width: 30, height: 20), cornerRadius: 3)
        plusBtn.fillColor = .darkGray
        plusBtn.strokeColor = .white
        plusBtn.position = CGPoint(x: 50, y: yPos)
        plusBtn.name = "plus_\(tag)"
        let plusLabel = SKLabelNode(text: "+\(increment)")
        plusLabel.fontSize = 10
        plusLabel.fontColor = .white
        plusLabel.verticalAlignmentMode = .center
        plusBtn.addChild(plusLabel)
        panel.addChild(plusBtn)
    }
    
    private func addBulletButtons(to panel: SKNode, yPos: CGFloat) {
        let amounts = [-100, -10, -1, 1, 10, 100]
        let startX: CGFloat = -70
        
        for (i, amount) in amounts.enumerated() {
            let btn = SKShapeNode(rectOf: CGSize(width: 22, height: 18), cornerRadius: 2)
            btn.fillColor = .darkGray
            btn.strokeColor = .white
            btn.position = CGPoint(x: startX + CGFloat(i) * 24, y: yPos)
            btn.name = "bullet_\(amount)"
            
            let label = SKLabelNode(text: amount > 0 ? "+\(amount)" : "\(amount)")
            label.fontSize = 7
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            btn.addChild(label)
            panel.addChild(btn)
        }
    }
    
    private func addActionButton(to panel: SKNode, title: String, name: String, yPos: CGFloat, color: SKColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: 120, height: 22), cornerRadius: 4)
        btn.fillColor = color.withAlphaComponent(0.3)
        btn.strokeColor = color
        btn.position = CGPoint(x: 0, y: yPos)
        btn.name = "action_\(name)"
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = title
        label.fontSize = 10
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        panel.addChild(btn)
    }
    
    private func handleBuildingMenuTouch(at location: CGPoint) {
        guard let panel = buildingMenuPanel, let building = selectedBuilding else { return }
        
        let localPos = panel.convert(location, from: cameraNode)
        
        for child in panel.children {
            guard let name = child.name else { continue }
            
            if let shape = child as? SKShapeNode, shape.contains(localPos) {
                if name.hasPrefix("plus_survivor") {
                    building.survivorQuota += 1
                } else if name.hasPrefix("minus_survivor") {
                    building.survivorQuota = max(0, building.survivorQuota - 1)
                } else if name.hasPrefix("plus_wood") {
                    building.woodQuota += 10
                } else if name.hasPrefix("minus_wood") {
                    building.woodQuota = max(0, building.woodQuota - 10)
                } else if name.hasPrefix("bullet_") {
                    if let amount = Int(name.replacingOccurrences(of: "bullet_", with: "")) {
                        building.bulletQuota = max(0, building.bulletQuota + amount)
                    }
                } else if name == "action_shootAir" {
                    if let sniper = building as? SniperTower {
                        sniper.shootInAir(gameState: gameState)
                    }
                } else if name == "action_holdFire" {
                    if let sniper = building as? SniperTower {
                        sniper.isHoldingFire = !sniper.isHoldingFire
                    }
                } else if name == "action_retreat" {
                    building.retreat(gameState: gameState)
                    gameState.destroyPlayerBuilding(building)
                    closeBuildingMenu()
                    return
                } else if name == "action_dependencies" {
                    if let depot = building as? Depot {
                        depot.showDependencies = !depot.showDependencies
                        updateConnectionLines()
                    }
                }
                
                // Refresh menu
                closeBuildingMenu()
                showBuildingMenu(for: building)
                return
            }
        }
    }
    
    private func closeBuildingMenu() {
        buildingMenuPanel?.removeFromParent()
        buildingMenuPanel = nil
        clearBuildingAoe()
    }
    
    private func showBuildingAoe(for building: PlayerBuilding) {
        clearBuildingAoe()
        
        guard building.type.hasAreaOfEffect else { return }
        
        let radius = building.type.areaOfEffectRadius
        let aoe = SKShapeNode(circleOfRadius: CGFloat(radius) * GridConfig.tileSize)
        aoe.fillColor = SKColor.gray.withAlphaComponent(0.15)
        aoe.strokeColor = building.type.color.withAlphaComponent(0.5)
        aoe.lineWidth = 1
        aoe.position = building.gridPosition.toScenePosition()
        aoe.zPosition = ZPosition.areaOfEffect
        
        aoeLayer.addChild(aoe)
        
        // Highlight buildings in range
        highlightBuildingsInRange(of: building.gridPosition, radius: radius, color: .green)
    }
    
    private func clearBuildingAoe() {
        aoeLayer.removeAllChildren()
        
        for bld in gameState.allPlayerBuildings {
            if let shape = bld.node as? SKShapeNode {
                shape.strokeColor = .white
                shape.lineWidth = 1
            }
        }
    }
    
    // MARK: - Sniper AOE Overlay
    
    private func updateSniperAoeOverlay() {
        sniperAoeOverlay?.removeFromParent()
        sniperAoeOverlay = nil
        
        guard showAllSniperAoe else { return }
        
        let overlay = SKNode()
        overlay.zPosition = ZPosition.areaOfEffect
        
        for sniper in gameState.sniperTowers {
            let aoe = SKShapeNode(circleOfRadius: CGFloat(GameBalance.sniperRange) * GridConfig.tileSize)
            aoe.fillColor = SKColor.white.withAlphaComponent(0.1)
            aoe.strokeColor = SKColor.purple.withAlphaComponent(0.3)
            aoe.lineWidth = 1
            aoe.position = sniper.gridPosition.toScenePosition()
            overlay.addChild(aoe)
        }
        
        gameLayer.addChild(overlay)
        sniperAoeOverlay = overlay
    }
    
    // MARK: - Connection Lines
    
    private func updateConnectionLines() {
        connectionLinesNode?.removeFromParent()
        connectionLinesNode = nil
        
        guard showAllConnections else { return }
        
        let linesNode = SKNode()
        linesNode.zPosition = ZPosition.connectionLines
        
        for depot in gameState.depots {
            let buildings = depot.getBuildingsInRange(gameState: gameState)
            
            for building in buildings {
                let line = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: depot.gridPosition.toScenePosition())
                path.addLine(to: building.gridPosition.toScenePosition())
                line.path = path
                line.strokeColor = SKColor.cyan.withAlphaComponent(0.4)
                line.lineWidth = 1
                linesNode.addChild(line)
            }
        }
        
        gameLayer.addChild(linesNode)
        connectionLinesNode = linesNode
    }
    
    // MARK: - Pause Menu
    
    private func togglePause() {
        if gameState.timeSpeed == .paused {
            gameState.timeSpeed = .normal
        } else {
            gameState.timeSpeed = .paused
        }
        updateUI()
    }
    
    private func cycleSpeed() {
        switch gameState.timeSpeed {
        case .paused: gameState.timeSpeed = .normal
        case .normal: gameState.timeSpeed = .fast
        case .fast: gameState.timeSpeed = .veryFast
        case .veryFast: gameState.timeSpeed = .normal
        }
        updateUI()
    }
    
    private func togglePauseMenu() {
        if isPauseMenuOpen {
            closePauseMenu()
        } else {
            openPauseMenu()
        }
    }
    
    private func openPauseMenu() {
        isPauseMenuOpen = true
        gameState.timeSpeed = .paused
        updateUI()
        
        let overlay = SKNode()
        overlay.zPosition = ZPosition.ui + 20
        
        let darkBg = SKShapeNode(rectOf: size)
        darkBg.fillColor = SKColor.black.withAlphaComponent(0.7)
        darkBg.strokeColor = .clear
        overlay.addChild(darkBg)
        
        let panel = SKShapeNode(rectOf: CGSize(width: 220, height: 280), cornerRadius: 15)
        panel.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 1.0)
        panel.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0)
        panel.lineWidth = 3
        overlay.addChild(panel)
        
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.text = "PAUSED"
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 100)
        overlay.addChild(title)
        
        let buttons = [
            ("Resume Game", "resume"),
            ("Save Game", "save"),
            ("Load Game", "load"),
            ("Reset Level", "reset"),
            ("Main Menu", "mainmenu")
        ]
        
        var yPos: CGFloat = 50
        for button in buttons {
            let btn = createPauseMenuButton(title: button.0, name: "pausemenu_\(button.1)")
            btn.position = CGPoint(x: 0, y: yPos)
            overlay.addChild(btn)
            yPos -= 42
        }
        
        cameraNode.addChild(overlay)
        pauseMenuOverlay = overlay
    }
    
    private func closePauseMenu() {
        isPauseMenuOpen = false
        pauseMenuOverlay?.removeFromParent()
        pauseMenuOverlay = nil
    }
    
    private func createPauseMenuButton(title: String, name: String) -> SKNode {
        let btn = SKNode()
        btn.name = name
        
        let bg = SKShapeNode(rectOf: CGSize(width: 180, height: 35), cornerRadius: 6)
        bg.fillColor = SKColor(red: 0.3, green: 0.15, blue: 0.15, alpha: 1.0)
        bg.strokeColor = SKColor(red: 0.6, green: 0.3, blue: 0.2, alpha: 1.0)
        btn.addChild(bg)
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = title
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        
        return btn
    }
    
    private func handlePauseMenuTouch(at location: CGPoint) {
        guard let overlay = pauseMenuOverlay else { return }
        
        for child in overlay.children {
            guard let name = child.name, name.hasPrefix("pausemenu_") else { continue }
            
            let localPos = overlay.convert(location, from: cameraNode)
            let distance = sqrt(pow(localPos.x - child.position.x, 2) + pow(localPos.y - child.position.y, 2))
            
            if distance < 100 && abs(localPos.y - child.position.y) < 20 {
                switch name {
                case "pausemenu_resume":
                    closePauseMenu()
                    gameState.timeSpeed = .normal
                case "pausemenu_reset":
                    closePauseMenu()
                    resetLevel()
                case "pausemenu_mainmenu":
                    goToMainMenu()
                default:
                    closePauseMenu()
                    showNotImplementedPopup(name)
                }
                return
            }
        }
        
        closePauseMenu()
    }
    
    private func showNotImplementedPopup(_ feature: String) {
        let popup = SKShapeNode(rectOf: CGSize(width: 200, height: 80), cornerRadius: 10)
        popup.fillColor = SKColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 0.95)
        popup.strokeColor = .orange
        popup.position = .zero
        popup.zPosition = ZPosition.popup
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = "Coming Soon!"
        label.fontSize = 16
        label.fontColor = .white
        popup.addChild(label)
        
        cameraNode.addChild(popup)
        
        let wait = SKAction.wait(forDuration: 1.5)
        let fade = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        popup.run(SKAction.sequence([wait, fade, remove]))
    }
    
    private func resetLevel() {
        let transition = SKTransition.fade(withDuration: 0.3)
        let newScene = GameScene(size: size)
        newScene.scaleMode = .resizeFill
        view?.presentScene(newScene, transition: transition)
    }
    
    private func goToMainMenu() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let mainMenu = MainMenuScene(size: size)
        mainMenu.scaleMode = .resizeFill
        view?.presentScene(mainMenu, transition: transition)
    }
    
    // MARK: - Visual Effects
    
    func showSniperShot(from: CGPoint, to: CGPoint, hit: Bool) {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        line.path = path
        line.strokeColor = hit ? .yellow : .gray
        line.lineWidth = hit ? 2 : 1
        line.zPosition = ZPosition.projectiles
        gameLayer.addChild(line)
        
        let fadeOut = SKAction.fadeOut(withDuration: 0.15)
        let remove = SKAction.removeFromParent()
        line.run(SKAction.sequence([fadeOut, remove]))
        
        if hit {
            let flash = SKShapeNode(circleOfRadius: 8)
            flash.fillColor = .red
            flash.strokeColor = .clear
            flash.position = to
            flash.zPosition = ZPosition.projectiles
            gameLayer.addChild(flash)
            
            let expand = SKAction.scale(to: 1.5, duration: 0.1)
            let fade = SKAction.fadeOut(withDuration: 0.1)
            flash.run(SKAction.sequence([expand, fade, remove]))
        }
    }
    
    func showGameOver(victory: Bool) {
        let overlay = SKShapeNode(rectOf: CGSize(width: 300, height: 220), cornerRadius: 15)
        overlay.fillColor = victory ?
            SKColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.95) :
            SKColor(red: 0.5, green: 0.1, blue: 0.1, alpha: 0.95)
        overlay.strokeColor = .white
        overlay.lineWidth = 3
        overlay.position = .zero
        overlay.zPosition = ZPosition.popup
        overlay.name = "gameOverOverlay"
        
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.fontSize = 28
        title.fontColor = .white
        title.text = victory ? "VICTORY!" : "GAME OVER"
        title.position = CGPoint(x: 0, y: 70)
        overlay.addChild(title)
        
        let buttons = [
            ("New Game", "gameover_newgame"),
            ("Load Game", "gameover_loadgame"),
            ("Title Screen", "gameover_title")
        ]
        
        var yPos: CGFloat = 10
        for button in buttons {
            let btn = createGameOverButton(title: button.0, name: button.1)
            btn.position = CGPoint(x: 0, y: yPos)
            overlay.addChild(btn)
            yPos -= 40
        }
        
        cameraNode.addChild(overlay)
        gameState.timeSpeed = .paused
    }
    
    private func createGameOverButton(title: String, name: String) -> SKNode {
        let btn = SKNode()
        btn.name = name
        
        let bg = SKShapeNode(rectOf: CGSize(width: 150, height: 30), cornerRadius: 5)
        bg.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        bg.strokeColor = .white
        btn.addChild(bg)
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = title
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        btn.addChild(label)
        
        return btn
    }
    
    // MARK: - Update Loop
    
    var lastUpdateTime: TimeInterval = 0
    
    override func update(_ currentTime: TimeInterval) {
        let deltaTime = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        
        gameState.update(deltaTime: deltaTime)
        updateUI()
        
        for sniper in gameState.sniperTowers {
            sniper.updateIndicator()
        }
        
        for depot in gameState.depots {
            depot.updateLabel()
        }
        
        if showAllSniperAoe {
            updateSniperAoeOverlay()
        }
        
        if showAllConnections {
            updateConnectionLines()
        }
    }
}
