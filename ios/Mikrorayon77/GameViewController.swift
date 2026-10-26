import UIKit
import SceneKit
import AVFoundation

final class GameViewController: UIViewController {
    private let world = World()
    private let store = SaveStore()
    private var state = GameState()
    private let sceneView = SCNView()
    private let status = UILabel()
    private let quest = UILabel()
    private let hint = UILabel()
    private let stick = UIView()
    private let thumb = UIView()
    private let talkButton = UIButton(type: .system)
    private var dialogueOpen = false
    private var windAudio: AVAudioPlayer?
    private var effectAudio: AVAudioPlayer?
    private var muted = false
    private let soundButton = UIButton(type: .system)
    private var origin: CGPoint?
    private var vector = CGPoint.zero
    private var clock: CADisplayLink?
    private var lastTime: Double = 0
    private var elapsed: Double = 0
    private var interaction: Double = 0
    private var saveTimer: Double = 0
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        state = store.load()
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        if let url = Bundle.main.url(forResource:"wind",withExtension:"wav",subdirectory:"Content") {
            windAudio = try? AVAudioPlayer(contentsOf:url); windAudio?.numberOfLoops = -1; windAudio?.volume = 0.2
        }
        sceneView.frame = view.bounds; sceneView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        sceneView.scene = world.scene; sceneView.pointOfView = world.camera
        sceneView.antialiasingMode = .multisampling2X; sceneView.preferredFramesPerSecond = 60
        sceneView.isPlaying = true; view.addSubview(sceneView)
        for label in [status,quest,hint] {
            label.translatesAutoresizingMaskIntoConstraints = false; label.textColor = .white
            label.backgroundColor = UIColor(red:0.09,green:0.16,blue:0.18,alpha:0.94); label.numberOfLines = 0
            label.textAlignment = .center; label.layer.cornerRadius = 12; label.clipsToBounds = true
            label.font = .systemFont(ofSize:14,weight:.semibold); view.addSubview(label)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            status.topAnchor.constraint(equalTo:safe.topAnchor,constant:8),status.leadingAnchor.constraint(equalTo:safe.leadingAnchor,constant:12),status.trailingAnchor.constraint(equalTo:safe.trailingAnchor,constant:-12),status.heightAnchor.constraint(equalToConstant:68),
            quest.topAnchor.constraint(equalTo:status.bottomAnchor,constant:8),quest.leadingAnchor.constraint(equalTo:status.leadingAnchor),quest.trailingAnchor.constraint(equalTo:status.trailingAnchor),quest.heightAnchor.constraint(equalToConstant:60),
            hint.bottomAnchor.constraint(equalTo:safe.bottomAnchor,constant:-12),hint.leadingAnchor.constraint(equalTo:status.leadingAnchor),hint.trailingAnchor.constraint(equalTo:status.trailingAnchor),hint.heightAnchor.constraint(equalToConstant:50)
        ])
        hint.text = "Finger halten und ziehen zum Laufen\nIn den Kreisen wird automatisch gearbeitet"
        for (item,diameter) in [(stick,CGFloat(100)),(thumb,CGFloat(38))] {
            item.frame.size = CGSize(width:diameter,height:diameter); item.layer.cornerRadius = diameter/2
            item.backgroundColor = UIColor.white.withAlphaComponent(0.18); item.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
            item.layer.borderWidth = 1; item.isUserInteractionEnabled = false; item.isHidden = true; view.addSubview(item)
        }
        talkButton.translatesAutoresizingMaskIntoConstraints = false
        talkButton.backgroundColor = UIColor(red:0.77,green:0.67,blue:0.48,alpha:1)
        talkButton.setTitleColor(.black, for:.normal); talkButton.layer.cornerRadius = 12
        talkButton.titleLabel?.font = .systemFont(ofSize:15,weight:.semibold)
        talkButton.addTarget(self,action:#selector(talk),for:.touchUpInside)
        view.addSubview(talkButton)
        NSLayoutConstraint.activate([
            talkButton.bottomAnchor.constraint(equalTo:hint.topAnchor,constant:-12),
            talkButton.trailingAnchor.constraint(equalTo:safe.trailingAnchor,constant:-12),
            talkButton.widthAnchor.constraint(equalToConstant:240),talkButton.heightAnchor.constraint(equalToConstant:46)
        ])
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        soundButton.setTitle("Ton an",for:.normal); soundButton.tintColor = .white
        soundButton.backgroundColor = UIColor(white:0.1,alpha:0.8); soundButton.layer.cornerRadius = 8
        soundButton.addTarget(self,action:#selector(toggleSound),for:.touchUpInside); view.addSubview(soundButton)
        NSLayoutConstraint.activate([soundButton.topAnchor.constraint(equalTo:quest.bottomAnchor,constant:8),soundButton.trailingAnchor.constraint(equalTo:safe.trailingAnchor,constant:-12),soundButton.widthAnchor.constraint(equalToConstant:84),soundButton.heightAnchor.constraint(equalToConstant:36)])
        let pan = UIPanGestureRecognizer(target:self,action:#selector(drag(_:))); pan.maximumNumberOfTouches = 1; sceneView.addGestureRecognizer(pan)
        NotificationCenter.default.addObserver(self,selector:#selector(suspend),name:UIApplication.willResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(resume),name:UIApplication.didBecomeActiveNotification,object:nil)
        if world.blocked(x:state.x,z:state.z) { state.x = 0; state.z = 10 }
        world.sync(state,time:0,moving:false); updateHUD(); resume()
    }
    @objc private func drag(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in:view)
        switch recognizer.state {
        case .began:
            let translation = recognizer.translation(in:view)
            origin = CGPoint(x:point.x-translation.x,y:point.y-translation.y)
            stick.center = origin!; thumb.center = origin!; stick.isHidden = false; thumb.isHidden = false
        case .changed:
            guard let start = origin else { return }
            let dx = point.x-start.x, dy = point.y-start.y
            let distance = max(1,sqrt(dx*dx+dy*dy)); let length = min(45,distance)
            vector = CGPoint(x:dx/distance*length/45,y:dy/distance*length/45)
            thumb.center = CGPoint(x:start.x+vector.x*45,y:start.y+vector.y*45)
        case .ended,.cancelled,.failed: clearInput()
        default: break
        }
    }
    private func clearInput() { origin = nil; vector = .zero; stick.isHidden = true; thumb.isHidden = true }
    @objc private func suspend() { clearInput(); clock?.invalidate(); clock = nil; lastTime = 0; sceneView.isPlaying = false; windAudio?.pause(); effectAudio?.stop(); store.save(state) }
    @objc private func resume() {
        guard clock == nil else { return }
        lastTime = 0; sceneView.isPlaying = true; if !muted { windAudio?.play() }
        let link = CADisplayLink(target:self,selector:#selector(tick(_:))); link.add(to:.main,forMode:.common); clock = link
    }
    @objc private func tick(_ link: CADisplayLink) {
        guard lastTime > 0 else { lastTime = link.timestamp; return }
        let dt = min(0.05,link.timestamp-lastTime); lastTime = link.timestamp
        guard !dialogueOpen, world.loadError == nil else { return }
        elapsed += dt
        // Screen-relative movement matches the elevated diagonal camera.
        let dx = (Float(vector.x)*0.894 + Float(vector.y)*0.447)*Float(dt)*4.2
        let dz = (-Float(vector.x)*0.447 + Float(vector.y)*0.894)*Float(dt)*4.2
        if !world.blocked(x:state.x+dx,z:state.z) { state.x += dx }
        if !world.blocked(x:state.x,z:state.z+dz) { state.z += dz }
        if vector != .zero { world.player.eulerAngles.y = atan2(dx,dz) }
        state.tick(dt)
        interaction += dt; saveTimer += dt
        if interaction >= 0.38 {
            interaction = 0
            if let site = world.sites.indices.min(by: { distance(world.sites[$0]) < distance(world.sites[$1]) }), distance(world.sites[site]) < 1.65, state.interact(at:site) {
                haptic.impactOccurred(intensity:0.45)
                if !muted {
                    let name = site == 0 ? "chop" : (site == 4 ? "repair" : "delivery")
                    if let url = Bundle.main.url(forResource:name,withExtension:"wav",subdirectory:"Content") {
                        effectAudio = try? AVAudioPlayer(contentsOf:url); effectAudio?.volume = 0.25; effectAudio?.play()
                    }
                }
                store.save(state)
            }
            updateHUD()
        }
        if saveTimer >= 10 { saveTimer = 0; store.save(state) }
        world.sync(state,time:elapsed,moving:vector != .zero)
    }
    private func distance(_ p: SCNVector3) -> Float { hypot(state.x-p.x,state.z-p.z) }
    private func updateHUD() {
        let npc = world.nearestNPC(x:state.x,z:state.z)
        let egg = world.nearestEgg(x:state.x,z:state.z)
        talkButton.isHidden = npc == nil && egg == nil
        if let i = npc, let person = world.content?.npcs[i] { talkButton.setTitle("Mit \(person.name) sprechen",for:.normal) }
        else { talkButton.setTitle("Untersuchen",for:.normal) }
        if let error = world.loadError { hint.text = error }
        status.text = "МИКРОРАЙОН 77 · 1977 · −31 °C\nHolz \(state.wood)   Nahrung \(state.food)   Wärme \(Int(state.fuel)) %"
        quest.text = state.objective + "\nVersorgt \(state.deliveredFood)/6 · Reparatur \(state.repairWood)/12"
        if !store.writable { hint.text = "Vorhandener Spielstand nicht lesbar.\nDieser Test überschreibt ihn nicht." }
    }
    @objc private func toggleSound() {
        muted.toggle(); soundButton.setTitle(muted ? "Ton aus" : "Ton an",for:.normal)
        if muted { windAudio?.pause(); effectAudio?.stop() } else { windAudio?.play() }
    }
    @objc private func talk() {
        guard !dialogueOpen else { return }
        var heading = "", message = ""
        if let i = world.nearestNPC(x:state.x,z:state.z), let person = world.content?.npcs[i] {
            heading = person.name + " · " + person.role; message = person.dialogue
            if !state.talked.contains(person.id) { state.talked.append(person.id) }
            if person.id == "worker" && state.repaired {
                state.worker = true
                message = "Das Dach hält. Ich übernehme das Sägen. Das fertige Holz liegt an der Werkstatt für dich bereit."
            }
        } else if let i = world.nearestEgg(x:state.x,z:state.z), let egg = world.content?.easterEggs[i] {
            heading = egg.title; message = egg.text
        } else { return }
        clearInput(); dialogueOpen = true; store.save(state)
        let alert = UIAlertController(title:heading,message:message,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Weiter",style:.default) { [weak self] _ in
            self?.dialogueOpen = false; self?.lastTime = 0; self?.updateHUD()
        })
        present(alert,animated:true)
    }
    deinit { clock?.invalidate(); NotificationCenter.default.removeObserver(self) }
}
