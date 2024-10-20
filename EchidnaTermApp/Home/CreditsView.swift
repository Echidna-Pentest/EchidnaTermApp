//
//  CreditsView.swift
//  EchidnaTermApp
//
//  Created by Miguel de Icaza on 6/17/21.
//  Copyright © 2021 Miguel de Icaza. All rights reserved.
//

import SwiftUI

struct LicenseFull: View {
    var name: String
    var url: String?
    var authors: String?
    var license: String

    var body: some View {
        ScrollView {
            VStack (alignment: .leading) {
                Text (name).font (.title)
                if let authors = authors {
                    Text ("Created by: \(authors)")
                        .font (.title2)
                }
                if let url = url {
                    HStack {
                        Text ("Project site: [\(url)](\(url))")
                        Spacer ()
                    }
                }
                Text ("")
                Text (license)
                    .font(.system(.body, design: .monospaced))
                    .minimumScaleFactor(0.3)
                    .scaledToFit()
                Spacer ()
            }.padding ([.leading, .trailing])
        }
    }
}

struct LicenseShort: View {
    var name: String
    var url: String?
    var authors: String?
    var license: String
    
    func getLicense () -> String {
        if let licenseUrl = Bundle.main.url(forResource:license, withExtension: "txt") {
            if let contents = try? String (contentsOf: licenseUrl) {
                return contents
            } else {
                return "Unable to load license"
            }
        } else {
            return "License not found"
        }
    }
    
    var body: some View {
        NavigationLink (destination: LicenseFull (name: name, url: url, authors: authors, license: getLicense ())) {
            VStack {
                HStack {
                    Text ("\(name)")
                        .bold()
                    Spacer ()
                }
                if let authors = authors {
                    HStack {
                        Text ("Authors: \(authors)")
                        Spacer ()
                    }
                }
            }
        }
    }
}
struct CreditsView: View {
    
    var body: some View {
        VStack {
            HStack {
                Text ("EchidnaTermApp is built based on the kind work of SwiftTermApp and implemented by integrating the features of Echidna to learn Cyber Security. Both of them are open source, and SwiftTermApp is available in the App Store for iPhone and iPad.")
            }.padding()
            List {
                // Seems like I no longer use it?
                //LicenseShort (name: "LazyView", authors: "Chris Eidhof", license: "")
                LicenseShort (name: "SwiftTermApp", url: "https://github.com/migueldeicaza/SwiftTermApp", authors: "Miguel de Icaza", license: "MIT")

                LicenseShort (name: "libssh", url: "https://www.libssh2.org", authors: "libssh2 project", license: "libssh")
                LicenseShort (name: "OpenSSL", authors: "Eric Young, OpenSSL project", license: "openssl_1_1_1h")
                LicenseShort (name: "SwCrypt", authors: "Soyer", license: "swcrypt")
                LicenseShort (name: "SwiftTerm", authors: "Miguel de Icaza, others", license: "swiftterm")
                LicenseShort (name: "SwiftUI-Introspect", url: "https://github.com/siteline/SwiftUI-Introspect/", authors: "SiteLine", license: "swiftui-introspect")
                LicenseShort (name: "Source Code Pro", url: "https://github.com/adobe-fonts/source-code-pro", authors: "Paul D. Hunt, Adobe Inc", license: "source-code-pro")
            }
        }
    }
}

struct CreditsView_Previews: PreviewProvider {
    static var previews: some View {
        CreditsView()
    }
}
