// Copyright 2021 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import SwiftUI

private struct TokenView: View {
  @ObservedObject var assetStore: AssetStore
  
  var body: some View {
    Button(action: {
      assetStore.isVisible.toggle()
    }) {
      HStack(spacing: 8) {
        Circle()
          .frame(width: 40, height: 40)
          .overlay(
            Image(uiImage: .init())
          )
          .clipShape(Circle())
        VStack(alignment: .leading) {
          Text(assetStore.token.name)
            .fontWeight(.semibold)
            .foregroundColor(Color(.bravePrimary))
          Text(assetStore.token.symbol.uppercased())
            .foregroundColor(Color(.secondaryBraveLabel))
        }
        .font(.footnote)
        Spacer()
        Image(systemName: "checkmark")
          .opacity(assetStore.isVisible ? 1 : 0)
      }
      .padding(.vertical, 8)
    }
  }
}

struct EditUserAssetsView: View {
  @ObservedObject var userAssetsStore: UserAssetsStore
  var assetsUpdated: () -> Void
  
  @Environment(\.presentationMode) @Binding private var presentationMode
  @State private var query = ""
  
  private var tokenStores: [AssetStore] {
    let query = query.lowercased()
    var stores = userAssetsStore.assetStores
    if !query.isEmpty {
      stores = stores.filter {
        $0.token.symbol.lowercased().contains(query) ||
        $0.token.name.lowercased().contains(query)
      }
    }
    return stores
      .sorted(by: { $0.token.symbol.caseInsensitiveCompare($1.token.symbol) == .orderedAscending })
      .sorted(by: { $0.isVisible && !$1.isVisible })
  }
  
  var body: some View {
    NavigationView {
      List {
        Section(
          header: WalletListHeaderView(
            title: Text("Assets") // NSLocalizedString
          )
            .osAvailabilityModifiers { content in
              if #available(iOS 15.0, *) {
                content // Padding already applied
              } else {
                content
                  .padding(.top)
              }
            }
        ) {
          ForEach(tokenStores, id: \.token.id) { store in
            TokenView(assetStore: store)
          }
        }
        .listRowBackground(Color(.secondaryBraveGroupedBackground))
      }
      .animation(.default, value: tokenStores)
      .navigationTitle("Edit Visible Assets") // NSLocalizedString
      .navigationBarTitleDisplayMode(.inline)
      .filterable(text: $query)
      .toolbar {
        ToolbarItemGroup(placement: .confirmationAction) {
          Button(action: {
            assetsUpdated()
            presentationMode.dismiss()
          }) {
            Text("Done") // NSLocalizedString
              .foregroundColor(Color(.braveOrange))
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

#if DEBUG
struct EditUserAssetsView_Previews: PreviewProvider {
  static var previews: some View {
    EmptyView()
  }
}
#endif