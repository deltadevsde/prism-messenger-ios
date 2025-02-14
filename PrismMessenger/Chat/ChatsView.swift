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
                Image(systemName: "square.and.pencil")
                    .foregroundColor(Color.blue)
            }.padding(.horizontal)
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ChatPreview(
                        username: "Sebastian Pusch",
                        imageURL: "https://pbs.twimg.com/profile_images/1836079646229614596/pL5ylf4__400x400.jpg",
                        message: "Hey Ryan"
                    )
                }.padding(.horizontal)
                Divider()
            }
        }
    }
}

struct ChatPreview: View {
    private let username: String
    private let imageURL: String
    private let message: String
    
    init(username: String, imageURL: String, message: String) {
        self.username = username
        self.imageURL = imageURL
        self.message = message
    }
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(username)
                    .font(.system(size: 16, weight: .semibold))
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

#Preview {
    ChatsView()
}
