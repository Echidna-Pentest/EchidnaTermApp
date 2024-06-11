//
//  AppDelegate.swift
//
//  Created by Miguel de Icaza on 4/25/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import SwiftUI
//import Shake

/// Databases (both configurations, local and cloudKit are here)
var globalDataController = DataController ()

@main
struct SampleApp: App {
    @State var dates = [Date]()
    @State var launchHost: Host?
    @StateObject var dataController: DataController
    @Environment(\.scenePhase) var scenePhase
    @StateObject private var chatViewModel = ChatViewModel()
    
    func extendLifetime () {
        // Attempts to keep the app alive, so our sockets are not killed within one second of going into the background
        var backgroundHandle: UIBackgroundTaskIdentifier? = nil
        backgroundHandle = UIApplication.shared.beginBackgroundTask(withName: "lifetime extender") {
            if let handle = backgroundHandle {
                UIApplication.shared.endBackgroundTask(handle)
            }
        }
    }
    init () {
//        if shakeKey != "" {
//            Shake.configuration.isCrashReportingEnabled = true
//            Shake.configuration.isAskForCrashDescriptionEnabled = true
//            Shake.start(clientId: shakeId, clientSecret: shakeKey)
//            if let userId = UIDevice.current.identifierForVendor?.uuidString {
//                Shake.registerUser(userId: userId)
//            }
//        }
        if settings.locationTrack {
            locationTrackerStart()
        }
//        for family in UIFont.familyNames.sorted() {
//            let names = UIFont.fontNames(forFamilyName: family)
//            print("Family: \(family) Font names: \(names)")
//        }
//        print ("here")
        
        _dataController = StateObject(wrappedValue: globalDataController)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    if Connections.shared.sessions.count > 0 {
                        locationTrackerResume()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    locationTrackerSuspend()
                }
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        extendLifetime ()
                        TargetTreeViewModel.shared.saveJSON()
                    }else if newPhase == .inactive {
                        TargetTreeViewModel.shared.saveJSON()
                    }else if newPhase == .active {
                        TargetTreeViewModel.shared.loadJSON()
                    }
                }
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(TargetTreeViewModel.shared)
                .environmentObject(chatViewModel)
        }
        .commands {
            TerminalCommands()
        }
        #if os(macOS)
        Settings {
            Text ("These are the macOS settings")
        }
        #endif
    }
}


class AppDelegate: NSObject, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        print("applicationWillTerminate")
        TargetTreeViewModel.shared.saveJSON()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("applicationDidEnterBackground")
        TargetTreeViewModel.shared.saveJSON()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("applicationWillResignActive")
        TargetTreeViewModel.shared.saveJSON()
    }
}
