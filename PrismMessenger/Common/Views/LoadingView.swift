//
//  LoadingView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            RadialGradientBackground()
            VStack {
                Spacer()
                Image("prism_white")
                Spacer()
                Image("prism_text_white").padding(.bottom, 30)
            }
        }
    }
}


struct RadialGradientBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            
            ZStack {
                // ellipse 18 (red)
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 239/255, green: 55/255, blue: 51/255), .clear]),
                        center: .init(x: 0.1, y: 0.2),
                        startRadius: screenWidth * 0.3,
                        endRadius: screenWidth * 1.7
                    )

                // ellipse 21 (blue)
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 117/255, green: 206/255, blue: 227/255), .clear]),
                        center: .init(x: 0.6, y: 0.7),
                        startRadius: screenWidth * 0.3,
                        endRadius: screenWidth * 1.6
                    )
                
                // ellipse 22 (yellow)
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 255/255, green: 188/255, blue: 63/255), .clear]),
                        center: .init(x: 1.2, y: 0.1),
                        startRadius: screenWidth * 0.3,
                        endRadius: screenWidth * 1.0
                    )

                // ellipse 20 (dark blue)
                    RadialGradient(
                        gradient: Gradient(colors: [Color(red: 31/255, green: 69/255, blue: 202/255), .clear]),
                        center: .init(x: -0.1, y: 1),
                        startRadius: screenWidth * 0.3,
                        endRadius: screenWidth * 1.3
                    )

                // ellipse 19 (purple)
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(red: 107/255, green: 79/255, blue: 255/255),
                            .clear
                        ]),
                        center: .init(x: 0.05, y: 0.6),
                        startRadius: 0,
                        endRadius: screenWidth * 0.9
                    )

            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    LoadingView()
}
