import SpriteKit

class TitleScene: SKScene {
    
    private var hasSkipped = false
    private var animationComplete = false
    
    override func didMove(to view: SKView) {
        backgroundColor = .black
        
        setupBackground()
        startTitleAnimation()
    }
    
    private func setupBackground() {
        // Dark gradient background
        let background = SKSpriteNode(color: SKColor(red: 0.1, green: 0.05, blue: 0.08, alpha: 1.0), size: size)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = 0
        addChild(background)
        
        // Add some atmospheric particles
        for _ in 0..<30 {
            let ember = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
            ember.fillColor = SKColor(red: CGFloat.random(in: 0.8...1.0), green: CGFloat.random(in: 0.2...0.4), blue: 0.1, alpha: 0.6)
            ember.strokeColor = .clear
            ember.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            ember.zPosition = 1
            addChild(ember)
            
            // Floating animation
            let moveUp = SKAction.moveBy(x: CGFloat.random(in: -20...20), y: CGFloat.random(in: 30...60), duration: Double.random(in: 3...6))
            let fadeOut = SKAction.fadeOut(withDuration: Double.random(in: 3...6))
            let group = SKAction.group([moveUp, fadeOut])
            let reset = SKAction.run {
                ember.position = CGPoint(
                    x: CGFloat.random(in: 0...self.size.width),
                    y: CGFloat.random(in: -20...0)
                )
                ember.alpha = 0.6
            }
            ember.run(SKAction.repeatForever(SKAction.sequence([group, reset])))
        }
    }
    
    private func startTitleAnimation() {
        // "SHATTERED COLONY" text
        let shatteredLabel = SKLabelNode(fontNamed: "Impact")
        shatteredLabel.text = "SHATTERED COLONY"
        shatteredLabel.fontSize = 52
        shatteredLabel.fontColor = SKColor(red: 0.9, green: 0.3, blue: 0.2, alpha: 1.0)
        shatteredLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        shatteredLabel.zPosition = 10
        shatteredLabel.alpha = 0
        shatteredLabel.name = "shatteredLabel"
        addChild(shatteredLabel)
        
        // "RELOADED" text
        let reloadedLabel = SKLabelNode(fontNamed: "Impact")
        reloadedLabel.text = "RELOADED"
        reloadedLabel.fontSize = 36
        reloadedLabel.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        reloadedLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 30)
        reloadedLabel.zPosition = 10
        reloadedLabel.alpha = 0
        reloadedLabel.name = "reloadedLabel"
        addChild(reloadedLabel)
        
        // "Tap to continue" prompt
        let tapLabel = SKLabelNode(fontNamed: "Helvetica")
        tapLabel.text = "Tap to continue"
        tapLabel.fontSize = 18
        tapLabel.fontColor = .white
        tapLabel.position = CGPoint(x: size.width / 2, y: 50)
        tapLabel.zPosition = 10
        tapLabel.alpha = 0
        tapLabel.name = "tapLabel"
        addChild(tapLabel)
        
        // Animation sequence
        let wait = SKAction.wait(forDuration: 0.5)
        let fadeInTitle = SKAction.fadeIn(withDuration: 2.0)
        let fadeInReloaded = SKAction.fadeIn(withDuration: 1.5)
        
        // Animate "SHATTERED COLONY"
        shatteredLabel.run(SKAction.sequence([wait, fadeInTitle]))
        
        // Animate "RELOADED" with delay
        reloadedLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            fadeInReloaded
        ]))
        
        // Show tap prompt and pulse it
        let showTapPrompt = SKAction.sequence([
            SKAction.wait(forDuration: 3.5),
            SKAction.fadeIn(withDuration: 0.5),
            SKAction.run { [weak self] in
                self?.animationComplete = true
            }
        ])
        
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ]))
        
        tapLabel.run(SKAction.sequence([showTapPrompt, pulse]))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !hasSkipped else { return }
        hasSkipped = true
        
        transitionToMainMenu()
    }
    
    private func transitionToMainMenu() {
        let transition = SKTransition.fade(withDuration: 0.8)
        let mainMenu = MainMenuScene(size: size)
        mainMenu.scaleMode = .resizeFill
        view?.presentScene(mainMenu, transition: transition)
    }
}
