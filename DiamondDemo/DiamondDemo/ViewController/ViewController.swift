//
//  ViewController.swift
//  DiamondDemo
//
//  Created by Bhautik Ziniya on 24/10/18.
//  Copyright © 2018 Magnates Technologies Pvt. Ltd. All rights reserved.
//

import UIKit
import SceneKit

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: SCNView!
    
    private var goldRingMaterial: SCNMaterial {
        let ringMaterial = SCNMaterial()
        ringMaterial.lightingModel = SCNMaterial.LightingModel.physicallyBased
        ringMaterial.diffuse.contents = UIImage.init(named: "gold-scuffed_Diffuse.png")
        ringMaterial.diffuse.intensity = 3
        ringMaterial.roughness.contents = 0.0
        ringMaterial.metalness.contents = 1.0
        ringMaterial.normal.contents = UIImage.init(named: "gold-scuffed_normal.png")
        return ringMaterial
    }
    
    private var diamondMaterial: SCNMaterial {
        let diamondMaterial = SCNMaterial()
        diamondMaterial.lightingModel = SCNMaterial.LightingModel.physicallyBased
        diamondMaterial.transparencyMode = .dualLayer
        diamondMaterial.fresnelExponent = 2.5
        diamondMaterial.isDoubleSided = true
        diamondMaterial.specular.contents = UIColor.init(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0)
        diamondMaterial.shininess = 56
        diamondMaterial.reflective.contents = UIColor.gray.withAlphaComponent(0.8)
        diamondMaterial.transparent.contents = UIColor.white.withAlphaComponent(0.8)
        diamondMaterial.roughness.contents = 0.0
        diamondMaterial.metalness.contents = 0.8
        let image = UIImage.init(named: "diamonds_texture.jpg")
        diamondMaterial.diffuse.contents = image
        return diamondMaterial
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.setupScene()
        self.addRingNode()
    }

    private func setupScene() {
        self.sceneView.scene = SCNScene()
        self.sceneView.allowsCameraControl = true
        let env = UIImage.init(named: "art.scnassets/environment.jpg")
        self.sceneView.scene!.lightingEnvironment.contents = env
        self.sceneView.delegate = self
        self.sceneView.scene?.background.contents = UIImage.init(named: "art.scnassets/environment.jpg")
    }
    
    private func addRingNode() {
        let ringScene = SCNScene(named: "art.scnassets/bezel_ring_1.scn")
        let ringNode = ringScene?.rootNode.childNode(withName: "object_1_None", recursively: false)
        ringNode?.name = "ring"
        ringNode?.geometry?.firstMaterial = self.goldRingMaterial
        
        let diamondScene = SCNScene(named: "art.scnassets/round_diamond_1_carat.scn")
        let diamondNode = diamondScene?.rootNode.childNode(withName: "Diamond_Round", recursively: false)
        diamondNode?.name = "diamond"
        diamondNode?.scale = SCNVector3Make(0.5, 0.5, 0.5)
        
        // Shaders for the material
        let material = SCNMaterial()
        let program = SCNProgram()
        program.vertexFunctionName = "vertexShader"
        program.fragmentFunctionName = "fragmentShader"
        program.isOpaque = false
        material.program = program
        diamondNode?.geometry?.materials = [material]
        
        ringNode?.addChildNode(diamondNode!)
        
        self.sceneView.scene!.rootNode.addChildNode(ringNode!)
    }
}

// MARK: - SCNSceneRendererDelegate
extension ViewController: SCNSceneRendererDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let diamondNode = self.sceneView.scene?.rootNode.childNode(withName: "diamond", recursively: true) else { return }
        guard let material = diamondNode.geometry?.firstMaterial else { return }
        
        var floatTime = Float(time)
        let timeData = Data(bytes: &floatTime, count: MemoryLayout<Float>.size)
        material.setValue(timeData, forKey: "time")
    }
}
