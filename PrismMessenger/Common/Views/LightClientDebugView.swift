//
//  LightClientDebugView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct LightClientDebugView: View {
    @EnvironmentObject var lightClientService: LightClientService
    @Environment(\.dismiss) private var dismiss
    
    @State private var logs: [String] = []
    @State private var startTime = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Header
                VStack(spacing: 12) {
                    Image(systemName: lightClientService.isVerified ? "checkmark.seal.fill" : "seal")
                        .font(.system(size: 60))
                        .foregroundColor(lightClientService.isVerified ? .green : .gray)
                    
                    Text(lightClientService.status)
                        .font(.headline)
                    
                    if let commitment = lightClientService.currentCommitment {
                        Text("Commitment: \(String(commitment.prefix(16)))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Height: \(lightClientService.currentHeight)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: lightClientService.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Logs - only showing recent ones
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                Text(log)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(logColor(for: log))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 2)
                                    .id(index)
                            }
                            
                            // Bottom anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.vertical)
                    }
                    .onChange(of: logs.count) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Clear Logs") {
                        logs.removeAll()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Retry") {
                        Task {
                            await lightClientService.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Light Client Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            startTime = Date()
            logs = ["[Debug View Opened]"]
            
            // Subscribe to new logs - no weak reference needed for value types
            lightClientService.setDebugLogHandler { newLog in
                Task { @MainActor in
                    logs.append(newLog)
                    
                    // Keep only last 500 logs to prevent memory issues
                    if logs.count > 500 {
                        logs.removeFirst()
                    }
                }
            }
        }
        .onDisappear {
            // Clear the debug log handler
            lightClientService.clearDebugLogHandler()
        }
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("✅") {
            return .green
        } else if log.contains("❌") {
            return .red
        } else if log.contains("⚠️") {
            return .orange
        } else if log.contains("🔄") {
            return .blue
        } else if log.contains("📊") || log.contains("📝") {
            return .purple
        } else if log.contains("🌟") {
            return .cyan
        }
        return .primary
    }
}
