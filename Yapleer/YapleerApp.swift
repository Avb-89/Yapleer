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

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(player)
        } label: {
            Image(systemName: player.isPlaying ? "flame.fill" : "flame")
        }
        .menuBarExtraStyle(.window)
    }
}
