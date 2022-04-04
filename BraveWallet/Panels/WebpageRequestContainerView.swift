// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import SwiftUI
import BraveUI

/// A container to present when a webpage wants to present some request to the user such as adding a suggested
/// token, change networks, authorize a transaction, etc.
struct WebpageRequestContainerView<DismissContent: ToolbarContent>: View {
  @ObservedObject var keyringStore: KeyringStore
  @ObservedObject var cryptoStore: CryptoStore
  var toolbarDismissContent: DismissContent
  
  var onDismiss: () -> Void
  
  var body: some View {
    UIKitNavigationView {
      Group {
        if let pendingRequest = cryptoStore.pendingWebpageRequest {
          switch pendingRequest {
          case let .signMessage(request):
            SignatureRequestView(
              request: request,
              keyringStore: keyringStore,
              onDismiss: { approved in
                cryptoStore.handleWebpageRequestResponse(.signMessage(approved: approved, id: request.id))
                onDismiss()
              }
            )
          default:
            EmptyView()
          }
        }
      }
      .toolbar {
        toolbarDismissContent
      }
    }
    .onAppear {
      // TODO: Fetch pending requests
    }
  }
}
