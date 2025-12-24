import SpriteKit

class CreditsScene: SKScene {
    
    private var creditsNode: SKNode!
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        setupBackground()
        setupCredits()
        setupBackButton()
    }
    
    private func setupBackground() {
        // Subtle starfield or dark background
        for _ in 0..<50 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            star.fillColor = SKColor(white: CGFloat.random(in: 0.3...0.8), alpha: 1.0)
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            star.zPosition = 0
            addChild(star)
            
            // Twinkle animation
            let fade = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: Double.random(in: 1...3)),
                SKAction.fadeAlpha(to: 1.0, duration: Double.random(in: 1...3))
            ])
            star.run(SKAction.repeatForever(fade))
        }
    }
    
    private func setupCredits() {
        creditsNode = SKNode()
        creditsNode.position = CGPoint(x: size.width / 2, y: -100)
        creditsNode.zPosition = 10
        addChild(creditsNode)
        
        // Credits content
        let creditsText = [
            "",
            "",
            "SHATTERED COLONY",
            "RELOADED",
            "",
            "",
            "",
            "A Game By",
            "",
            "C&I Productions",
            "",
            "",
            "",
            "",
            "Based on the original",
            "Shattered Colony",
            "",
            "",
            "",
            "",
            "Programming",
            "C&I Productions",
            "",
            "",
            "Game Design",
            "C&I Productions",
            "",
            "",
            "Art Direction",
            "C&I Productions",
            "",
            "",
            "",
            "",
            "Special Thanks",
            "",
            "To all the fans of",
            "the original game",
            "",
            "",
            "",
            "",
            "",
            "© 2024 C&I Productions",
            "All Rights Reserved",
            "",
            "",
            "",
            "",
            "Thank you for playing!",
            "",
            "",
            ""
        ]
        
        var yOffset: CGFloat = 0
        let lineSpacing: CGFloat = 35
        
        for (index, line) in creditsText.enumerated() {
            let label = SKLabelNode(fontNamed: getFont(for: line, index: index))
            label.text = line
            label.fontSize = getFontSize(for: line, index: index)
            label.fontColor = getFontColor(for: line, index: index)
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: yOffset)
            creditsNode.addChild(label)
            
            yOffset -= lineSpacing
        }
        
        // Scroll animation
        let totalHeight = CGFloat(creditsText.count) * lineSpacing + size.height
        let scrollDuration = Double(creditsText.count) * 0.8
        
        let scrollUp = SKAction.moveBy(x: 0, y: totalHeight, duration: scrollDuration)
        let wait = SKAction.wait(forDuration: 2.0)
        let goToMenu = SKAction.run { [weak self] in
            self?.returnToMainMenu()
        }
        
        creditsNode.run(SKAction.sequence([scrollUp, wait, goToMenu]))
    }
    
    private func getFont(for line: String, index: Int) -> String {
        if line == "SHATTERED COLONY" || line == "RELOADED" {
            return "Impact"
        } else if line == "C&I Productions" {
            return "Helvetica-Bold"
        } else if line.contains("©") {
            return "Helvetica"
        }
        return "Helvetica-Bold"
    }
    
    private func getFontSize(for line: String, index: Int) -> CGFloat {
        if line == "SHATTERED COLONY" {
            return 42
        } else if line == "RELOADED" {
            return 32
        } else if line == "C&I Productions" {
            return 36
        } else if line.isEmpty {
            return 20
        }
        return 22
    }
    
    private func getFontColor(for line: String, index: Int) -> SKColor {
        if line == "SHATTERED COLONY" {
            return SKColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0)
        } else if line == "RELOADED" {
            return SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        } else if line == "C&I Productions" {
            return SKColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
        } else if line.contains("©") || line == "All Rights Reserved" {
            return .gray
        }
        return .white
    }
    
    private func setupBackButton() {
        let backButton = SKShapeNode(rectOf: CGSize(width: 100, height: 35), cornerRadius: 6)
        backButton.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 0.8)
        backButton.strokeColor = .gray
        backButton.lineWidth = 1
        backButton.position = CGPoint(x: 70, y: size.height - 30)
        backButton.zPosition = 100
        backButton.name = "backButton"
        
        let label = SKLabelNode(fontNamed: "Helvetica")
        label.text = "← Back"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        backButton.addChild(label)
        
        addChild(backButton)
        
        // Hint text
        let hint = SKLabelNode(fontNamed: "Helvetica")
        hint.text = "Tap anywhere to skip"
        hint.fontSize = 12
        hint.fontColor = SKColor.gray
        hint.position = CGPoint(x: size.width / 2, y: 20)
        hint.zPosition = 100
        addChild(hint)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)
        
        for node in touchedNodes {
            if node.name == "backButton" || node.parent?.name == "backButton" {
                returnToMainMenu()
                return
            }
        }
        
        // Tap anywhere to skip
        returnToMainMenu()
    }
    
    private func returnToMainMenu() {
        let transition = SKTransition.fade(withDuration: 0.5)
        let mainMenu = MainMenuScene(size: size)
        mainMenu.scaleMode = .resizeFill
        view?.presentScene(mainMenu, transition: transition)
    }
}
