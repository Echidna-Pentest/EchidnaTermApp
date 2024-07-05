//
//  MetalSwiftUI.swift
//  EchidnaTermApp
//
//  Created by Miguel de Icaza on 6/6/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

class MetalHostView: UIView {
    var metal: MetalHost!
    
    public init (frame: CGRect, fragmentName: String)
    {
        let metalLayer = CAMetalLayer()
        metalLayer.pixelFormat = .bgra8Unorm
        metal = MetalHost(target: metalLayer, fragmentName: fragmentName)
        super.init (frame: frame)
        if metal != nil {
            layer.addSublayer(metalLayer)
            metal.startRunning()
        }
    }

    public required init (coder: NSCoder)
    {
        fatalError()
    }

    deinit {
        DispatchQueue.main.async {
            self.metal.stopRunning()
        }
    }
    
    public override var frame: CGRect {
        didSet {
            metal.target.frame = frame
        }
    }
}

struct MetalView: UIViewRepresentable {
    let shaderFunc: String
    
    func makeUIView(context: Context) -> UIView {
        let view = MetalHostView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), fragmentName: shaderFunc)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context)
    {
        
    }
}

struct MetalSwiftUI_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text ("Top")
            HStack {
                Text ("Hello")
                MetalView (shaderFunc: "digitalbrain_fragment_texture")
                Text ("World")
            }
            Text ("Bottom")
        }
    }
}
