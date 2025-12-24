import SpriteKit

class MainMenuScene: SKScene {
    
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.08, blue: 0.12, alpha: 1.0)
        
        setupBackground()
        setupTitle()
        setupMenuButtons()
    }
    
    private func setupBackground() {
        // Dark atmospheric background
        let background = SKSpriteNode(color: SKColor(red: 0.08, green: 0.05, blue: 0.1, alpha: 1.0), size: size)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = 0
        addChild(background)
        
        // Add subtle ember particles on right side
        for _ in 0..<20 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...2))
            ember.fillColor = SKColor(red: CGFloat.random(in: 0.6...0.9), green: CGFloat.random(in: 0.2...0.4), blue: 0.1, alpha: 0.4)
            ember.strokeColor = .clear
            ember.position = CGPoint(
                x: CGFloat.random(in: size.width * 0.5...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            ember.zPosition = 0.5
            addChild(ember)
            
            // Floating animation
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: 20...40), duration: Double.random(in: 4...8))
            let fadeOut = SKAction.fadeOut(withDuration: Double.random(in: 4...8))
            let group = SKAction.group([moveUp, fadeOut])
            let reset = SKAction.run {
                ember.position = CGPoint(
                    x: CGFloat.random(in: self.size.width * 0.5...self.size.width),
                    y: CGFloat.random(in: -20...0)
                )
                ember.alpha = 0.4
            }
            ember.run(SKAction.repeatForever(SKAction.sequence([group, reset])))
        }
        
        // Dark gradient overlay on left for menu
        let leftOverlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.4, height: size.height))
        leftOverlay.fillColor = SKColor.black.withAlphaComponent(0.7)
        leftOverlay.strokeColor = .clear
        leftOverlay.position = CGPoint(x: size.width * 0.2, y: size.height / 2)
        leftOverlay.zPosition = 1
        addChild(leftOverlay)
    }
    
    private func setupTitle() {
        // Title container
        let titleY = size.height - 60
        
        let shatteredLabel = SKLabelNode(fontNamed: "Impact")
        shatteredLabel.text = "SHATTERED COLONY"
        shatteredLabel.fontSize = 32
        shatteredLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0)
        shatteredLabel.horizontalAlignmentMode = .left
        shatteredLabel.position = CGPoint(x: 30, y: titleY)
        shatteredLabel.zPosition = 10
        addChild(shatteredLabel)
        
        let reloadedLabel = SKLabelNode(fontNamed: "Impact")
        reloadedLabel.text = "RELOADED"
        reloadedLabel.fontSize = 24
        reloadedLabel.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        reloadedLabel.horizontalAlignmentMode = .left
        reloadedLabel.position = CGPoint(x: 30, y: titleY - 35)
        reloadedLabel.zPosition = 10
        addChild(reloadedLabel)
    }
    
    private func setupMenuButtons() {
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 45
        let startY = size.height / 2 + 60
        let spacing: CGFloat = 55
        
        let menuItems = ["New Game", "Load File", "Browse Maps", "Credits"]
        
        for (index, title) in menuItems.enumerated() {
            let button = createMenuButton(title: title, width: buttonWidth, height: buttonHeight)
            button.position = CGPoint(x: 30 + buttonWidth / 2, y: startY - CGFloat(index) * spacing)
            button.name = "menu_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
            addChild(button)
        }
        
        // Version label
        let versionLabel = SKLabelNode(fontNamed: "Helvetica")
        versionLabel.text = "Version 6.0"
        versionLabel.fontSize = 12
        versionLabel.fontColor = .gray
        versionLabel.horizontalAlignmentMode = .left
        versionLabel.position = CGPoint(x: 30, y: 20)
        versionLabel.zPosition = 10
        addChild(versionLabel)
    }
    
    private func createMenuButton(title: String, width: CGFloat, height: CGFloat) -> SKNode {
        let container = SKNode()
        
        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.3, green: 0.15, blue: 0.15, alpha: 0.9)
        background.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0)
        background.lineWidth = 2
        background.zPosition = 5
        container.addChild(background)
        
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = title
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 6
        container.addChild(label)
        
        container.zPosition = 10
        return container
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)
        
        for node in touchedNodes {
            if let name = node.name ?? node.parent?.name {
                handleMenuTap(name)
                return
            }
        }
    }
    
    private func handleMenuTap(_ name: String) {
        switch name {
        case "menu_new_game":
            transitionToNewGameMenu()
        case "menu_load_file":
            showPlaceholderPopup()
        case "menu_browse_maps":
            showPlaceholderPopup()
        case "menu_credits":
            showCreditsScreen()
        default:
            break
        }
    }
    
    private func transitionToNewGameMenu() {
        let transition = SKTransition.push(with: .left, duration: 0.3)
        let newGameMenu = NewGameMenuScene(size: size)
        newGameMenu.scaleMode = .resizeFill
        view?.presentScene(newGameMenu, transition: transition)
    }
    
    private func showCreditsScreen() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let creditsScene = CreditsScene(size: size)
        creditsScene.scaleMode = .resizeFill
        view?.presentScene(creditsScene, transition: transition)
    }
    
    private func showPlaceholderPopup() {
        // Create popup overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.fillColor = SKColor.black.withAlphaComponent(0.6)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.zPosition = 50
        overlay.name = "popupOverlay"
        addChild(overlay)
        
        // Popup box
        let popup = SKShapeNode(rectOf: CGSize(width: 300, height: 180), cornerRadius: 15)
        popup.fillColor = SKColor(red: 0.15, green: 0.12, blue: 0.18, alpha: 1.0)
        popup.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 1.0)
        popup.lineWidth = 3
        popup.position = CGPoint(x: size.width / 2, y: size.height / 2)
        popup.zPosition = 51
        popup.name = "popup"
        addChild(popup)
        
        // Popup text
        let text = SKLabelNode(fontNamed: "Helvetica-Bold")
        text.text = "Hooray I work!"
        text.fontSize = 24
        text.fontColor = .white
        text.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        text.zPosition = 52
        text.name = "popupText"
        addChild(text)
        
        // "Cool beans" button
        let coolButton = createPopupButton(title: "Cool beans")
        coolButton.position = CGPoint(x: size.width / 2 - 70, y: size.height / 2 - 40)
        coolButton.name = "popup_dismiss"
        addChild(coolButton)
        
        // "Alrighty then" button
        let alrightButton = createPopupButton(title: "Alrighty then")
        alrightButton.position = CGPoint(x: size.width / 2 + 70, y: size.height / 2 - 40)
        alrightButton.name = "popup_dismiss"
        addChild(alrightButton)
    }
    
    private func createPopupButton(title: String) -> SKNode {
        let container = SKNode()
        
        let background = SKShapeNode(rectOf: CGSize(width: 120, height: 35), cornerRadius: 6)
        background.fillColor = SKColor(red: 0.4, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .orange
        background.lineWidth = 1
        container.addChild(background)
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = title
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)
        
        container.zPosition = 53
        return container
    }
    
    func dismissPopup() {
        childNode(withName: "popupOverlay")?.removeFromParent()
        childNode(withName: "popup")?.removeFromParent()
        childNode(withName: "popupText")?.removeFromParent()
        enumerateChildNodes(withName: "popup_dismiss") { node, _ in
            node.removeFromParent()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)
        
        for node in touchedNodes {
            if node.name == "popup_dismiss" || node.parent?.name == "popup_dismiss" {
                dismissPopup()
                return
            }
            if node.name == "popupOverlay" {
                dismissPopup()
                return
            }
        }
    }
}
