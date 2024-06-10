//
//  HostConnectionError.swift
//  HostConnectionError
//
//  Created by Miguel de Icaza on 7/22/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import Foundation
import SwiftUI

struct HostConnectionError: View {
    @State var host: Host
    @State var error: String
    @State var ok: () -> () = { }
    
    var body: some View {
        VStack (alignment: .center){
            HStack (alignment: .center){
                Image (systemName: "desktopcomputer.trianglebadge.exclamationmark")
                    .symbolRenderingMode(.multicolor)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30)
                    .padding (10)
                Text ("\(host.alias)")
                    .font(.title)
                Spacer ()
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            //.background(.yellow)
            VStack (alignment: .center){
                Text ("`\(host.hostname):\(String (host.port))` - Connection error\n\nDetails: \(error)")
                    .padding ([.bottom])
                HStack (alignment: .center, spacing: 20) {
                    Button ("Ok") { ok () }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
            .padding()
            Spacer ()
        }
    }
}

struct HostConnectionError_Previews: PreviewProvider {
    static var previews: some View {
        WrapperView ()
    }
    
    struct WrapperView: View {
        var host: Host
        
        init () {
            host = CHost (context: DataController.preview.container.viewContext)
            host.alias = "dbserver"
            host.hostname = "dbserver.domain.com"
        }
        
        var body: some View {
            HostConnectionError(host: host, error: "Connection closed")
        }
    }
}
