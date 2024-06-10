//
//  MetalHost.swift
//
//  Created by Miguel de Icaza on 5/31/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//
// Elements and flow from Shadertweak by Warren Moore and
// the tutorials at http://metalbyexample.com as well as the
//

import Foundation
import Metal
import UIKit

///
/// The MetalHost takes care of rendering to the screen
///
/// It requires a CAMetalLayer as a parameter, which should be added as a sublayer to the
/// view.layer where the contents should be displayed.   The methods `startRunning`
/// and `stopRunning` should be invoked to setup the CADisplayLink.   Optionally,
/// the `didMoveToWindow` method can be called from the view's `didMoveToWindow`
/// with the view parameter and this will do the right thing.
///
/// To load a new shader, call the `tryUpdateLibrary` method with the new compiled
/// library.   The expectation of this library is similar to what is shipped ont his sample as
/// Shader.metal, and operates as a fragment shader.
///
public class MetalHost {
    var target: CAMetalLayer
    var device: MTLDevice
    var queue: MTLCommandQueue
    var vertexBuffer: MTLBuffer
    var displayLink: CADisplayLink?
    var library: MTLLibrary
    var renderPipeline: MTLRenderPipelineState
    var startTime, time, deltaTime: CFTimeInterval
    var uniformsBuffer: MTLBuffer
    var fragmentName: String
    
    /// These are the Shadertoy-like uniforms
    struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var deltaTime: Float
        var frameIndex: Int32
    }
    
    let vertices = [
        Vertex (position: [-1, -1, 0, 1]),
        Vertex (position: [-1,  1, 0, 0]),
        Vertex (position: [ 1, -1, 1, 1]),
        Vertex (position: [ 1,  1, 1, 0]),
    ]

    struct Vertex {
        var position: SIMD4<Float>
    }
    
    public init? (target: CAMetalLayer, fragmentName: String)
    {
        self.target = target
        self.fragmentName = fragmentName
        guard let device = MTLCreateSystemDefaultDevice() else {
            return nil
        }
        self.device = device
        guard let queue = device.makeCommandQueue() else {
            return nil
        }
        self.queue = queue
        guard let library = device.makeDefaultLibrary() else {
            return nil
        }
        self.library = library
        let size = vertices.count * MemoryLayout<Vertex>.stride
        guard let buffer = device.makeBuffer(bytes: vertices, length: size, options: .cpuCacheModeWriteCombined) else { return nil }
        buffer.label = "terminal.verterbuffer"
        vertexBuffer = buffer
        guard let rps = MetalHost.makeRenderPipelineState (device: device, library: library, fragmentFunction: fragmentName) else {
            return nil
        }
        self.renderPipeline = rps
        
        // Uniform buffer
        guard let uniformBuffer = device.makeBuffer(length: MemoryLayout<Uniforms>.stride) else { return nil }
        uniformBuffer.label = "swifterm.migueldeicaza"
        uniformBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        self.uniformsBuffer = uniformBuffer

        // Time
        startTime = CACurrentMediaTime()
        time = startTime
        deltaTime = 0
        
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc func appMovedToBackground () {
        stopRunning()
    }

    @objc func appMovedToForeground () {
        startRunning()
    }
    
    deinit {
        stopRunning()
        let notificationCenter = NotificationCenter.default

        notificationCenter.removeObserver(self)
    }
    
    static func makeRenderPipelineState (device: MTLDevice, library: MTLLibrary, fragmentFunction: String) -> MTLRenderPipelineState?
    {
        // Make the pipeline descriptor
        guard let vertexFn = library.makeFunction(name: "vertex_reshape"),
            let fragmentFn = library.makeFunction(name: fragmentFunction) else {
            return nil
        }
        
        let vd = MTLVertexDescriptor ()

        // position
        vd.attributes [0].format = .float2
        vd.attributes [0].offset = 0
        vd.attributes [0].bufferIndex = 0

        // texCoords
        vd.attributes [1].format = .float2
        vd.attributes [1].offset = 2 * MemoryLayout<Float>.size
        vd.attributes [1].bufferIndex = 0
        
        vd.layouts[0].stepRate = 1
        vd.layouts[0].stepFunction = .perVertex
        vd.layouts[0].stride = 4 * MemoryLayout<Float>.size

        let pipelineDesc = MTLRenderPipelineDescriptor ()
        pipelineDesc.vertexFunction = vertexFn
        pipelineDesc.fragmentFunction = fragmentFn
        pipelineDesc.vertexDescriptor = vd
        pipelineDesc.colorAttachments [0].pixelFormat = .bgra8Unorm
        
        return try? device.makeRenderPipelineState(descriptor: pipelineDesc)
    }
    
    /// Starts the timer that renders to the screen
    public func startRunning ()
    {
        if displayLink == nil {
            displayLink = CADisplayLink (target: self, selector: #selector(tick(from:)))
            displayLink?.add(to: .main, forMode: .common)
        }
    }
    
    /// Stops the timer that renders to the screen
    public func stopRunning ()
    {
        if displayLink == nil { return }
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Use this method to replace the MTLLibrary being displayed
    public func tryUpdateLibrary (newLibrary: MTLLibrary, fragmentName: String) -> Bool {
        if let rps = MetalHost.makeRenderPipelineState(device: device, library: newLibrary, fragmentFunction: fragmentName) {
            library = newLibrary
            renderPipeline = rps
            return true
        }
        return false
    }
    
    func redraw()
    {
        // Prepare Uniforms
        let time = CACurrentMediaTime()-self.startTime
        let deltaTime = time - self.time
        let ptr = uniformsBuffer.contents().assumingMemoryBound(to: Uniforms.self)
        ptr.pointee = Uniforms(
            resolution: [Float (target.bounds.width), Float (target.bounds.height)],
            time: Float (time),
            deltaTime: Float (deltaTime),
            frameIndex: 0)

        self.time = time
        self.deltaTime = deltaTime
        
        guard let drawable = self.target.nextDrawable(),
            let commandBuffer = self.queue.makeCommandBuffer() else { return }
     
        // RenderPassDescriptor
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments [0].texture = drawable.texture
        renderPass.colorAttachments [0].clearColor = MTLClearColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        renderPass.colorAttachments [0].loadAction = .clear
        renderPass.colorAttachments [0].storeAction = .store
        
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
        encoder.setRenderPipelineState(renderPipeline)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        // TODO add textures here
        encoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        // (&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    public func didMoveToWindow (view: UIView) {
        stopRunning()
        guard let window = view.window else {
            return
        }
        target.contentsScale = window.screen.nativeScale
        startRunning()
    }
    
    @objc func tick (from displayLink: CADisplayLink) {
         redraw ()
    }
}
