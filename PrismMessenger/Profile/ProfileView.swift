//
//  ProfileView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData
import CryptoKit

struct ProfileView: View {
    @Query var users: [UserData]

    var body: some View {
        if let user = users.first {
            VStack(alignment: .leading) {
                HStack {
                    Text("Profile")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(Color.blue)
                }.padding(.horizontal)
                Divider()
                Text(user.username).padding(.horizontal)
                Spacer()
            }
        } else {
            LoadingView()
        }
    }
}

#Preview {
    ProfileView().modelContainer(DataController.previewContainer)
}

@MainActor
class DataController {
    static let previewContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: UserData.self, configurations: config)

            let user = UserData(signedPrekey: P256.Signing.PrivateKey(), username: "ExampleUsername")
            container.mainContext.insert(user)

            return container
        } catch {
            fatalError("Failed to create model container for previewing: \(error.localizedDescription)")
        }
    }()
}
