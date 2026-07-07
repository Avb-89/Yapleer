//
//  YapleerApp.swift
//  Yapleer
//
//  Created by SITIS on 6/25/26.
//

import SwiftUI
import AppKit

@main
struct YapleerApp: App {
    @StateObject private var player = PlayerService()
    @StateObject private var authState = AuthState()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environmentObject(player)
                .environmentObject(authState)
        } label: {
            Image(systemName: player.isPlaying ? "flame.fill" : "flame")
        }
        .menuBarExtraStyle(.window)
    }
}
