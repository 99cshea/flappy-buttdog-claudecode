import SpriteKit

// MARK: - Physics Categories
private struct Physics {
    static let buttdog: UInt32 = 0x1 << 0
    static let pipe:    UInt32 = 0x1 << 1
    static let ground:  UInt32 = 0x1 << 2
    static let gap:     UInt32 = 0x1 << 3
}

// MARK: - Game State
private enum GameState {
    case idle, playing, dead
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes
    private var buttdog: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    private var bestLabel: SKLabelNode!
    private var messageLabel: SKNode!
    private var groundNode: SKSpriteNode!
    private var scrollingGround: SKNode!

    // MARK: - State
    private var state: GameState = .idle
    private var score = 0
    private var bestScore: Int {
        get { UserDefaults.standard.integer(forKey: "bestScore") }
        set { UserDefaults.standard.set(newValue, forKey: "bestScore") }
    }

    // MARK: - Constants
    private let flapImpulse: CGFloat  = 420
    private let gravity: CGFloat      = -12
    private let pipeGap: CGFloat      = 190
    private let pipeWidth: CGFloat    = 72
    private let pipeSpeed: CGFloat    = 180   // points per second
    private let spawnInterval: Double = 2.2
    private let groundHeight: CGFloat = 70
    private let groundScrollSpeed: TimeInterval = 3.0

    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        physicsWorld.gravity    = CGVector(dx: 0, dy: gravity)
        physicsWorld.contactDelegate = self

        setupBackground()
        setupScrollingGround()
        setupGround()
        setupButtdog()
        setupHUD()
        showIdleMessage()
    }

    private func setupBackground() {
        // Sky gradient via two layered nodes
        let sky = SKSpriteNode(color: SKColor(red: 0.44, green: 0.76, blue: 0.98, alpha: 1), size: size)
        sky.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sky.zPosition = -10
        addChild(sky)

        // Simple cloud sprites
        for i in 0..<3 {
            let cloud = makeCloud()
            cloud.position = CGPoint(x: CGFloat(i) * size.width / 2.5 + 60,
                                     y: size.height * 0.72 + CGFloat(i) * 30)
            cloud.zPosition = -5
            addChild(cloud)
            let move = SKAction.moveBy(x: -size.width - 120, y: 0, duration: 18 + Double(i) * 4)
            let reset = SKAction.moveBy(x: size.width + 240, y: 0, duration: 0)
            cloud.run(SKAction.repeatForever(SKAction.sequence([move, reset])))
        }
    }

    private func makeCloud() -> SKNode {
        let node = SKNode()
        let sizes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0, 0, 50, 30), (-30, 10, 40, 25), (30, 10, 40, 25)
        ]
        for (x, y, w, h) in sizes {
            let blob = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
            blob.fillColor = .white
            blob.strokeColor = .clear
            blob.alpha = 0.85
            blob.position = CGPoint(x: x, y: y)
            node.addChild(blob)
        }
        return node
    }

    private func setupScrollingGround() {
        scrollingGround = SKNode()
        addChild(scrollingGround)

        for i in 0...2 {
            let strip = makeGroundStrip()
            strip.position = CGPoint(x: CGFloat(i) * size.width, y: groundHeight / 2)
            strip.name = "groundStrip"
            scrollingGround.addChild(strip)
        }
    }

    private func makeGroundStrip() -> SKSpriteNode {
        let strip = SKSpriteNode(color: SKColor(red: 0.49, green: 0.77, blue: 0.34, alpha: 1),
                                 size: CGSize(width: size.width + 2, height: groundHeight))
        // Darker stripe for grass texture
        let dirt = SKSpriteNode(color: SKColor(red: 0.76, green: 0.60, blue: 0.42, alpha: 1),
                                size: CGSize(width: size.width + 2, height: groundHeight * 0.55))
        dirt.position = CGPoint(x: 0, y: -groundHeight * 0.22)
        strip.addChild(dirt)
        return strip
    }

    private func setupGround() {
        // Invisible physics ground
        groundNode = SKSpriteNode(color: .clear, size: CGSize(width: size.width * 3, height: 2))
        groundNode.position = CGPoint(x: size.width / 2, y: groundHeight)
        groundNode.physicsBody = SKPhysicsBody(rectangleOf: groundNode.size)
        groundNode.physicsBody?.isDynamic = false
        groundNode.physicsBody?.categoryBitMask = Physics.ground
        groundNode.physicsBody?.contactTestBitMask = Physics.buttdog
        addChild(groundNode)

        // Ceiling
        let ceiling = SKSpriteNode(color: .clear, size: CGSize(width: size.width * 3, height: 2))
        ceiling.position = CGPoint(x: size.width / 2, y: size.height)
        ceiling.physicsBody = SKPhysicsBody(rectangleOf: ceiling.size)
        ceiling.physicsBody?.isDynamic = false
        ceiling.physicsBody?.categoryBitMask = Physics.ground
        ceiling.physicsBody?.contactTestBitMask = Physics.buttdog
        addChild(ceiling)
    }

    private func setupButtdog() {
        let texture = SKTexture(imageNamed: "buttdog")
        buttdog = SKSpriteNode(texture: texture)
        buttdog.size = CGSize(width: 88, height: 66)
        // Flip horizontally so dog faces right (toward pipes)
        buttdog.xScale = -1
        buttdog.position = CGPoint(x: size.width * 0.28, y: size.height * 0.55)
        buttdog.zPosition = 5

        let body = SKPhysicsBody(circleOfRadius: 28)
        body.isDynamic = false
        body.allowsRotation = false
        body.categoryBitMask    = Physics.buttdog
        body.contactTestBitMask = Physics.pipe | Physics.ground | Physics.gap
        body.collisionBitMask   = 0
        buttdog.physicsBody = body

        addChild(buttdog)

        // Idle hover animation
        let hover = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.7),
            SKAction.moveBy(x: 0, y: -8, duration: 0.7)
        ])
        buttdog.run(SKAction.repeatForever(hover), withKey: "hover")
    }

    private func setupHUD() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        scoreLabel.fontSize  = 64
        scoreLabel.fontColor = .white
        scoreLabel.position  = CGPoint(x: size.width / 2, y: size.height - 90)
        scoreLabel.zPosition = 20
        scoreLabel.text = "0"
        scoreLabel.isHidden = true
        addChild(scoreLabel)

        bestLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        bestLabel.fontSize  = 22
        bestLabel.fontColor = SKColor(white: 1, alpha: 0.85)
        bestLabel.position  = CGPoint(x: size.width / 2, y: size.height - 120)
        bestLabel.zPosition = 20
        bestLabel.isHidden  = true
        addChild(bestLabel)
    }

    private func showIdleMessage() {
        messageLabel = makeBubbleLabel(text: "Tap to start!", fontSize: 34)
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.36)
        messageLabel.zPosition = 20
        addChild(messageLabel)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.6),
            SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        ])
        messageLabel.run(SKAction.repeatForever(pulse))
    }

    // MARK: - Game Flow
    private func startGame() {
        state = .playing

        messageLabel.removeFromParent()
        scoreLabel.isHidden = false
        score = 0
        scoreLabel.text = "0"

        buttdog.removeAction(forKey: "hover")
        buttdog.physicsBody?.isDynamic = true
        flap()
        startScrollingGround()
        scheduleNextPipe()
    }

    private func flap() {
        guard state == .playing else { return }
        buttdog.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        buttdog.physicsBody?.applyImpulse(CGVector(dx: 0, dy: flapImpulse))

        buttdog.removeAction(forKey: "tilt")
        let tiltUp = SKAction.rotate(toAngle: 0.35, duration: 0.12)
        buttdog.run(tiltUp, withKey: "tilt")
    }

    private func startScrollingGround() {
        let move  = SKAction.moveBy(x: -size.width, y: 0, duration: groundScrollSpeed)
        let reset = SKAction.moveBy(x: size.width,  y: 0, duration: 0)
        scrollingGround.run(SKAction.repeatForever(SKAction.sequence([move, reset])),
                            withKey: "scroll")
    }

    private func scheduleNextPipe() {
        guard state == .playing else { return }
        let wait  = SKAction.wait(forDuration: spawnInterval)
        let spawn = SKAction.run { [weak self] in
            self?.spawnPipe()
            self?.scheduleNextPipe()
        }
        run(SKAction.sequence([wait, spawn]), withKey: "pipeScheduler")
    }

    private func spawnPipe() {
        guard state == .playing else { return }

        let safeBottom = groundHeight + 80
        let safeTop    = size.height - 80
        let available  = safeTop - safeBottom - pipeGap
        let gapBottom  = CGFloat.random(in: safeBottom ... safeBottom + available)
        let gapTop     = gapBottom + pipeGap

        let container = SKNode()
        container.position = CGPoint(x: size.width + pipeWidth, y: 0)
        container.name = "pipeContainer"

        // Bottom pipe
        let bottomH = gapBottom - groundHeight
        let bottom  = makePipe(width: pipeWidth, height: bottomH, isTop: false)
        bottom.position = CGPoint(x: 0, y: groundHeight + bottomH / 2)
        container.addChild(bottom)

        // Top pipe
        let topH   = size.height - gapTop
        let top    = makePipe(width: pipeWidth, height: topH, isTop: true)
        top.position = CGPoint(x: 0, y: gapTop + topH / 2)
        container.addChild(top)

        // Gap sensor (scores a point)
        let sensor = SKNode()
        sensor.position = CGPoint(x: 0, y: gapBottom + pipeGap / 2)
        sensor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 8, height: pipeGap))
        sensor.physicsBody?.isDynamic = false
        sensor.physicsBody?.collisionBitMask = 0
        sensor.physicsBody?.categoryBitMask    = Physics.gap
        sensor.physicsBody?.contactTestBitMask = Physics.buttdog
        container.addChild(sensor)

        // Move left and auto-remove
        let distance  = size.width + pipeWidth * 2 + 40
        let duration  = TimeInterval(distance / pipeSpeed)
        let moveLeft  = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        let remove    = SKAction.removeFromParent()
        container.run(SKAction.sequence([moveLeft, remove]))

        addChild(container)
    }

    private func makePipe(width: CGFloat, height: CGFloat, isTop: Bool) -> SKNode {
        let node = SKNode()

        let body = SKSpriteNode(color: SKColor(red: 0.28, green: 0.72, blue: 0.28, alpha: 1),
                                size: CGSize(width: width, height: height))
        body.physicsBody = SKPhysicsBody(rectangleOf: body.size)
        body.physicsBody?.isDynamic = false
        body.physicsBody?.categoryBitMask    = Physics.pipe
        body.physicsBody?.contactTestBitMask = Physics.buttdog
        node.addChild(body)

        // Cap (darker, wider)
        let capH: CGFloat = 28
        let cap = SKSpriteNode(color: SKColor(red: 0.18, green: 0.58, blue: 0.18, alpha: 1),
                               size: CGSize(width: width + 14, height: capH))
        cap.position = CGPoint(x: 0, y: isTop ? -(height / 2) + capH / 2 : (height / 2) - capH / 2)
        cap.physicsBody = SKPhysicsBody(rectangleOf: cap.size)
        cap.physicsBody?.isDynamic = false
        cap.physicsBody?.categoryBitMask    = Physics.pipe
        cap.physicsBody?.contactTestBitMask = Physics.buttdog
        node.addChild(cap)

        // Dark outline/shadow strip
        let outline = SKSpriteNode(color: SKColor(red: 0.10, green: 0.46, blue: 0.10, alpha: 0.5),
                                   size: CGSize(width: 8, height: height))
        outline.position = CGPoint(x: -width / 2 + 4, y: 0)
        node.addChild(outline)

        return node
    }

    private func triggerDeath() {
        guard state == .playing else { return }
        state = .dead

        removeAction(forKey: "pipeScheduler")
        scrollingGround.removeAction(forKey: "scroll")

        // Freeze all pipe containers
        enumerateChildNodes(withName: "pipeContainer") { node, _ in
            node.removeAllActions()
        }

        buttdog.removeAllActions()
        buttdog.physicsBody?.isDynamic = false

        // Death shake
        let shakeRight = SKAction.moveBy(x: 8,  y: 0, duration: 0.05)
        let shakeLeft  = SKAction.moveBy(x: -8, y: 0, duration: 0.05)
        let shake      = SKAction.sequence([shakeRight, shakeLeft, shakeRight, shakeLeft,
                                            SKAction.moveBy(x: 0, y: 0, duration: 0)])
        run(shake)

        // Update best score
        if score > bestScore { bestScore = score }

        // Show game over panel after brief pause
        let delay = SKAction.wait(forDuration: 0.6)
        let show  = SKAction.run { [weak self] in self?.showGameOver() }
        run(SKAction.sequence([delay, show]))
    }

    private func showGameOver() {
        let panel = makeGameOverPanel()
        panel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        panel.zPosition = 30
        panel.setScale(0.3)
        panel.alpha = 0
        addChild(panel)

        let appear = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.25),
            SKAction.fadeIn(withDuration: 0.25)
        ])
        panel.run(appear)
    }

    private func makeGameOverPanel() -> SKNode {
        let panel = SKNode()
        panel.name = "gameOverPanel"

        // Background card
        let card = SKShapeNode(rectOf: CGSize(width: 280, height: 240), cornerRadius: 20)
        card.fillColor   = SKColor(white: 0.12, alpha: 0.88)
        card.strokeColor = SKColor(white: 1, alpha: 0.2)
        card.lineWidth   = 2
        panel.addChild(card)

        // "GAME OVER" title
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text      = "GAME OVER"
        title.fontSize  = 34
        title.fontColor = SKColor(red: 1, green: 0.35, blue: 0.3, alpha: 1)
        title.position  = CGPoint(x: 0, y: 68)
        panel.addChild(title)

        // Score
        let scoreLine = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLine.text      = "Score: \(score)"
        scoreLine.fontSize  = 28
        scoreLine.fontColor = .white
        scoreLine.position  = CGPoint(x: 0, y: 20)
        panel.addChild(scoreLine)

        // Best
        let bestLine = SKLabelNode(fontNamed: "AvenirNext-Medium")
        bestLine.text      = "Best:  \(bestScore)"
        bestLine.fontSize  = 22
        bestLine.fontColor = SKColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
        bestLine.position  = CGPoint(x: 0, y: -18)
        panel.addChild(bestLine)

        // Tap to restart hint
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        hint.text      = "Tap to play again"
        hint.fontSize  = 18
        hint.fontColor = SKColor(white: 0.75, alpha: 1)
        hint.position  = CGPoint(x: 0, y: -70)
        panel.addChild(hint)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.55),
            SKAction.fadeAlpha(to: 1.0, duration: 0.55)
        ])
        hint.run(SKAction.repeatForever(pulse))

        return panel
    }

    private func restartGame() {
        let fresh = GameScene(size: size)
        fresh.scaleMode = scaleMode
        view?.presentScene(fresh, transition: SKTransition.fade(withDuration: 0.3))
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        switch state {
        case .idle:
            startGame()
        case .playing:
            flap()
        case .dead:
            restartGame()
        }
    }

    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let masks = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if masks & Physics.gap != 0 && masks & Physics.buttdog != 0 {
            score += 1
            scoreLabel.text = "\(score)"

            // Pop animation on score
            let pop = SKAction.sequence([
                SKAction.scale(to: 1.25, duration: 0.06),
                SKAction.scale(to: 1.0,  duration: 0.08)
            ])
            scoreLabel.run(pop)
        } else if masks & Physics.buttdog != 0 && state == .playing {
            triggerDeath()
        }
    }

    // MARK: - Update
    override func update(_ currentTime: TimeInterval) {
        guard state == .playing else { return }

        // Tilt buttdog downward as it falls
        if let vy = buttdog.physicsBody?.velocity.dy {
            let targetAngle = max(min(vy * 0.0018, 0.35), -1.1)
            buttdog.zRotation = buttdog.zRotation + (targetAngle - buttdog.zRotation) * 0.18
        }
    }

    // MARK: - Helpers
    private func makeBubbleLabel(text: String, fontSize: CGFloat) -> SKNode {
        let node  = SKNode()
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text      = text
        label.fontSize  = fontSize
        label.fontColor = SKColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
        label.verticalAlignmentMode = .center

        let bg = SKShapeNode(rectOf: CGSize(width: label.frame.width + 32,
                                            height: label.frame.height + 20),
                             cornerRadius: 14)
        bg.fillColor   = SKColor(white: 1, alpha: 0.88)
        bg.strokeColor = SKColor(white: 0.7, alpha: 0.5)
        bg.lineWidth   = 1.5

        node.addChild(bg)
        node.addChild(label)
        return node
    }
}
