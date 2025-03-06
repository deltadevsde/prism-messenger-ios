//
//  FeaturesView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import CryptoKit
import SwiftData

struct Feature: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let description: String
    
    static let samples = [
        Feature(image: "message.circle.fill",
               title: "Prism",
               description: "Trust-minimized communication the way it's meant to be"),
        Feature(image: "lock.shield.fill",
               title: "Can't be evil",
               description: "Applies advanced cryptographic techniques to ensure your data is not tampered with"),
        Feature(image: "person.fill",
               title: "Verified Identities",
               description: "Proves identities without manually comparing security codes")
    ]
}


struct FeaturesView: View {
    @Binding var path: NavigationPath
    
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 20) {
            TabView(selection: $currentPage) {
                ForEach(Array(Feature.samples.enumerated()), id: \.element.id) { index, feature in
                    FeatureCard(feature: feature)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            
            // Custom dot indicators
            HStack(spacing: 8) {
                ForEach(0..<Feature.samples.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom)
            
            Button(action: {
                path.append("signup")
            }) {
                Text("Start Messaging")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .navigationDestination(for: String.self) { _ in
                SignUpView()
            }
        }
    }
}

struct FeatureCard: View {
    let feature: Feature
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: feature.image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text(feature.title)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(feature.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

// Preview removed temporarily for testing

