//
//  ChatsView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct ChatsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Messages")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "square.and.pencil").foregroundColor(Color.blue)
            }.padding()
            Divider()
            Spacer()
        }
    }
}

#Preview {
    ChatsView()
}
