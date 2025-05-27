//
//  SmallProfilePictureView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct SmallProfilePictureView: View {
    let imageURL: String?
    let size: CGFloat
    let action: () -> Void

    init(imageURL: String?, size: CGFloat = 40, action: @escaping () -> Void) {
        self.imageURL = imageURL
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            AsyncImage(url: imageURL.flatMap(URL.init)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty, .failure:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.gray)
                @unknown default:
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
