//
//  TerminalViewController.swift
//
//  This view controller can be used for any TerminalViews (currently just SshTerminalView, but hopefully a Mosh one later)
//
//  Created by Miguel de Icaza on 5/5/20.
//  Copyright © 2020 Miguel de Icaza. All rights reserved.
//

import Foundation
import UIKit
import SwiftTerm
import SwiftUI

///
/// Implements the host for the TerminalView and takes care of the keyboard showing/hiding
/// as well as screenshotting the current session, so it can be used elsewhere
///
/// This can be constructed either with a Host, to trigger the connection workflow, or with a
/// TerminalView to become the host for an existing view.
///
class TerminalViewController: UIViewController {
    // If this is nil, it will trigger the SSH workflow.
    var terminalView: SshTerminalView?
    var interactive: Bool
    var host: Host
    static var Serial: Int = 0
    var serial: Int
    var isTerminalViewFullScreen = false
    var targetTreeHostingController: UIHostingController<TargetTreeView>?
    var candidateCommandHostingController: UIHostingController<CandidateCommandView>?

    static var shared: TerminalViewController?

    func isTerminalViewAttached() -> Bool {
        if let t = terminalView {
            return view.subviews.contains(t)
        }
        return false
    }
    
    {
    init(host: Host, interactive: Bool, serial: Int = -1) {
        TerminalViewController.Serial += 1
        self.host = host
        self.interactive = interactive
        self.serial = serial
        globalDataController.used(host: host)
        super.init(nibName: nil, bundle: nil)
        TerminalViewController.shared = self
    }

    init(terminalView: SshTerminalView, interactive: Bool) {
        TerminalViewController.Serial += 1
        self.terminalView = terminalView
        self.host = terminalView.host
        self.interactive = interactive
        self.serial = terminalView.serial
        globalDataController.used(host: host)
        super.init(nibName: nil, bundle: nil)
        TerminalViewController.shared = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startConnection() -> SshTerminalView? {
        do {
            let tv = try SshTerminalView(frame: view.frame, host: host)
            tv.serial = self.serial
            if host.style == "" {
                tv.applyTheme(theme: settings.getTheme())
            } else {
                tv.applyTheme(theme: settings.getTheme(themeName: host.style))
            }
            return tv
        } catch MyError.noValidKey(let msg) {
            terminalViewCreationError(msg)
        } catch {
            terminalViewCreationError("general")
        }
        return nil
    }

    override func viewDidLoad() {
        print("viewDidLoad")
        super.viewDidLoad()
        
        if terminalView == nil {
            terminalView = startConnection()
        }
        guard let terminalView = terminalView else {
            return
        }
        
        self.terminalView = terminalView
        
        if #available(iOS 15.0, *) {
            terminalView.disableFirstResponderDuringViewRehosting = true
            view.addSubview(terminalView)
            terminalView.disableFirstResponderDuringViewRehosting = false
            terminalView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                terminalView.leftAnchor.constraint(equalTo: view.leftAnchor),
                terminalView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                terminalView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6)
            ])
            
            let targetTreeView = TargetTreeView()
            targetTreeHostingController = UIHostingController(rootView: targetTreeView)
            addChild(targetTreeHostingController!)
            view.addSubview(targetTreeHostingController!.view)
            targetTreeHostingController!.didMove(toParent: self)
            targetTreeHostingController!.view.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                targetTreeHostingController!.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                targetTreeHostingController!.view.rightAnchor.constraint(equalTo: view.rightAnchor),
                targetTreeHostingController!.view.leftAnchor.constraint(equalTo: terminalView.rightAnchor),
                targetTreeHostingController!.view.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4)
            ])

            let candidateCommandView = CandidateCommandView()
            candidateCommandHostingController = UIHostingController(rootView: candidateCommandView)
            addChild(candidateCommandHostingController!)
            view.addSubview(candidateCommandHostingController!.view)
            candidateCommandHostingController!.didMove(toParent: self)
            candidateCommandHostingController!.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                candidateCommandHostingController!.view.topAnchor.constraint(equalTo: targetTreeHostingController!.view.bottomAnchor),
                candidateCommandHostingController!.view.rightAnchor.constraint(equalTo: view.rightAnchor),
                candidateCommandHostingController!.view.leftAnchor.constraint(equalTo: terminalView.rightAnchor),
                candidateCommandHostingController!.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
            
//            setupToggleButton()

            CommandManager.shared.setHostname(hostname: self.host.hostname)
        } else {
            terminalView.frame = view.frame
            terminalView.translatesAutoresizingMaskIntoConstraints = true
            terminalView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            view.addSubview(terminalView)
        }
        if let ml = terminalView.metalLayer {
            view.layer.insertSublayer(ml, at: 0)
        }
        if interactive {
            _ = terminalView.becomeFirstResponder()
        } else {
            let _ = terminalView.resignFirstResponder()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !interactive && isTerminalViewAttached() {
            terminalView!.frame = view.frame
        }
    }
    /*
    private let toggleButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "arrow.up.left.and.arrow.down.right")
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(toggleTerminalViewFullscreen), for: .touchUpInside)
        return button
    }()
    
    private func setupToggleButton() {
        view.addSubview(toggleButton)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toggleButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            toggleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
*/
    private func updateToggleButtonIcon() {
        let imageName = isTerminalViewFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        let image = UIImage(systemName: imageName)
//        toggleButton.setImage(image, for: .normal)
    }
    
    @objc public func toggleTerminalViewFullscreen() {
        guard let terminalView = terminalView else { return }

        isTerminalViewFullScreen.toggle()

        NSLayoutConstraint.deactivate(terminalView.constraints)
        NSLayoutConstraint.deactivate(targetTreeHostingController!.view.constraints)
        NSLayoutConstraint.deactivate(candidateCommandHostingController!.view.constraints)

        if isTerminalViewFullScreen {
            terminalView.frame = view.frame
            terminalView.translatesAutoresizingMaskIntoConstraints = true
            terminalView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            targetTreeHostingController?.view.isHidden = true
            candidateCommandHostingController?.view.isHidden = true
        } else {
            terminalView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                terminalView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                terminalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                terminalView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                terminalView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6)
            ])
            targetTreeHostingController?.view.isHidden = false
            candidateCommandHostingController?.view.isHidden = false
        }
        
        updateToggleButtonIcon()

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
//        view.bringSubviewToFront(toggleButton)
    }

    func terminalViewCreationError(_ msg: String) {
        let alert = UIAlertController(title: "Connection Problem", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
            NSLog("The \"OK\" alert occured.")
        }))
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
        
    static var visibleTerminal: AppTerminalView?
    static var visibleControler: TerminalViewController?
    
    override func viewWillAppear(_ animated: Bool) {
        TerminalViewController.visibleTerminal = terminalView
        TerminalViewController.visibleControler = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TerminalViewController.visibleTerminal = nil
        TerminalViewController.visibleControler = nil
    }
}


typealias Controller = TerminalViewController

//
// This is the wrapper to use the TerminalViewController in Swift
//
struct SwiftUITerminal: UIViewControllerRepresentable {
    var terminalView: SshTerminalView?
    class MutableSideData {
        var viewController: TerminalViewController?
    }
    
    typealias UIViewControllerType = TerminalViewController
    
    enum Kind {
        case host (host: Host, createNew: Bool)
        case rehost (rehost: SshTerminalView)
    }
    
    var kind: Kind
    var interactive: Bool
    let mutableSideData: MutableSideData
    
    /// Creates a new SwiftUITerminal, either it creates a new one based on a host configuration (`host` is not nil), in which
    /// case the `createNew` parameter indicates if this should createa  new host or not.   If `host` is nil, then
    /// this assumes that this is going to rehost an existing SshTerminalView, in that case, `existing` should not
    /// be nil.
    init (host: Host?, existing: SshTerminalView?, createNew: Bool, interactive: Bool) {
        self.mutableSideData = MutableSideData ()
        if host == nil {
            assert (existing != nil)
            self.terminalView = existing
            kind = .rehost(rehost: existing!)
        } else {
            assert (existing == nil)
            kind = .host(host: host!, createNew: createNew)
        }
        self.interactive = interactive
    }

    // This might be called in a view that has no viewController
    func rehost ()
    {
        if let tv = terminalView {
            if let vc = mutableSideData.viewController {
                vc.view.addSubview(tv)
            }
        }
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<SwiftUITerminal>) -> TerminalViewController {
        
        switch kind {
        case .host(host: let host, createNew: let createNew):
            if !createNew {
                if let v = Connections.lookupActiveTerminal(host: host) {
                    let ret = TerminalViewController(terminalView: v, interactive: interactive)
                    mutableSideData.viewController = ret
                    return ret
                }
            }
            let ret = TerminalViewController (host: host, interactive: interactive, serial: createNew ? -2 : -1)
            mutableSideData.viewController = ret
            return ret
        case .rehost(rehost: let terminalView):
            let ret = TerminalViewController(terminalView: terminalView, interactive: interactive)
            mutableSideData.viewController = ret
            return ret
        }
    }
  
    func updateUIViewController(_ uiViewController: TerminalViewController, context: UIViewControllerRepresentableContext<SwiftUITerminal>) {
    }
}

