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
        Button {
            action()
        } label: {
            Group {
                if let imageURL = imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: size))
                        .foregroundColor(.gray)
                        .frame(width: size, height: size)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
