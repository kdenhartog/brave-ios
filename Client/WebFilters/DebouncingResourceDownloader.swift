// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared
import BraveShared

private let log = Logger.browserLogger

/// An helper class that manages the debouncing list and offers convenience methods
class DebouncingResourceDownloader {
  /// Object representing an item in the debouncing.json file found here:
  /// https://github.com/brave/adblock-lists/blob/master/brave-lists/debounce.json
  struct Matcher: Decodable {
    private enum CodingKeys: String, CodingKey {
      case include
      case exclude
      case action
      case param
    }

    enum Action: String {
      case base64
      case redirect
    }

    let include: [String]
    let exclude: [String]
    let action: String
    let param: String

    /// Actions in a strictly typed format and split up into an array
    /// - Note: Unrecognized actions will be filtered out
    lazy var actions: [Action] = {
      let actionStrings = action.split(separator: ",")
      return actionStrings.compactMap({ Action(rawValue: String($0)) })
    }()
  }

  private static let queue = DispatchQueue(label: "com.brave.debouncing-dispatch-queue")
  static let shared = DebouncingResourceDownloader()

  private let networkManager: NetworkManager
  private let resourceURL = URL(string: "https://raw.githubusercontent.com/brave/adblock-lists/master/brave-lists/debounce.json")!
  private let fileName = "ios-debouce"
  private let folderName = "debounce-data"
  private var savedFileURL: URL?
  private var matchers: [Matcher]?

  /// Initialized with year 1970 to force adblock fetch at first launch.
  private(set) var lastFetchDate = Date(timeIntervalSince1970: 0)
  /// How frequently to fetch the data
  private lazy var fetchInterval = AppConstants.buildChannel.isPublic ? 6.hours : 10.minutes

  private init(networkManager: NetworkManager = NetworkManager()) {
    self.networkManager = networkManager
  }

  /// Downloads the required resources if they are not available. Loads any cached data if it already exists.
  func startLoading() {
    let now = Date()
    let resourceURL = self.resourceURL
    let fileName = [self.fileName, "json"].joined(separator: ".")
    let etagFileName = [fileName, "etag"].joined(separator: ".")
    let folderName = self.folderName

    do {
      // Load data from disk if we have it
      if let cachedData = try self.dataFromDocument(inFolder: folderName, fileName: fileName) {
        // Decode the data and store it for later user
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        self.matchers = try jsonDecoder.decode([Matcher].self, from: cachedData)
      }
    } catch {
      log.error(error)
    }

    if now.timeIntervalSince(lastFetchDate) >= fetchInterval {
      lastFetchDate = now

      let networkManager = self.networkManager
      let etag: String?

      do {
        etag = try self.stringFromDocument(inFolder: folderName, fileName: etagFileName)
      } catch {
        etag = nil
        log.error(error)
      }

      Task.detached(priority: .userInitiated) { [weak self] in
        guard let self = self else { return }

        let resource = try await networkManager.downloadResource(
          with: resourceURL,
          resourceType: .cached(etag: etag),
          checkLastServerSideModification: !AppConstants.buildChannel.isPublic,
          customHeaders: [:])

        guard !resource.data.isEmpty else {
          return
        }

        do {
          // Save the data to file
          self.savedFileURL = try self.writeDataToDisk(data: resource.data, inFolder: folderName, fileName: fileName)

          // Decode the data and store it for later user
          let jsonDecoder = JSONDecoder()
          jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
          self.matchers = try jsonDecoder.decode([Matcher].self, from: resource.data)
        } catch {
          log.error(error)
        }
      }
    }
  }

  /// Get a possible redirect url for the given URL.
  ///
  /// This code uses the patterns in the downloaded matchers to determine if a redirect action is required.
  /// If it is, a redirect url will be returned provided we can extract it from the url
  func redirectURL(for url: URL) -> URL? {
    guard matchers != nil else { return nil }
    return url.redirectURL(for: &matchers!)
  }

  private func dataFromDocument(inFolder folderName: String, fileName: String) throws -> Data? {
    let folderUrl = try FileManager.default.getOrCreateFolderDirectory(name: folderName)
    let fileUrl = folderUrl.appendingPathComponent(fileName)
    return FileManager.default.contents(atPath: fileUrl.path)
  }

  private func stringFromDocument(inFolder folderName: String, fileName: String) throws -> String? {
    let folderUrl = try FileManager.default.getOrCreateFolderDirectory(name: folderName)
    let fileUrl = folderUrl.appendingPathComponent(fileName)
    guard let data = FileManager.default.contents(atPath: fileUrl.path) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func writeDataToDisk(data: Data, inFolder folderName: String, fileName: String) throws -> URL {
    let folderUrl = try FileManager.default.getOrCreateFolderDirectory(name: folderName)
    let fileUrl = folderUrl.appendingPathComponent(fileName)
    try data.write(to: fileUrl, options: [.atomic])
    return fileUrl
  }
}

enum DirectoryError: Error {
  case cannotFindSearchPathDirectory
}

private extension FileManager {
  /// Creates a folder at given location if it is required.
  func ensureFolderDirectory(folderDirectory: inout URL, excludeFromBackups: Bool = true) throws {
    if fileExists(atPath: folderDirectory.path) { return }
    try createDirectory(at: folderDirectory, withIntermediateDirectories: true, attributes: nil)

    if excludeFromBackups {
      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = true
      try folderDirectory.setResourceValues(resourceValues)
    }
  }

  /// Creates a folder at given location and returns its URL
  ///
  /// - Note: If folder already exists, returns it's URL as well.
  func getOrCreateFolderDirectory(
    name: String,
    at location: SearchPathDirectory = .applicationSupportDirectory
  ) throws -> URL {
    guard let documentsDirectory = location.url else {
      throw DirectoryError.cannotFindSearchPathDirectory
    }

    var folderDirectory = documentsDirectory.appendingPathComponent(name)
    try ensureFolderDirectory(folderDirectory: &folderDirectory, excludeFromBackups: true)
    return folderDirectory
  }
}

extension URL {
  /// Get a possible redirect url for the given URL and the given matchers.
  ///
  /// Since the actions are lazily constructed, the matchers will be lazily created but nothing will be changed.
  /// This code uses the patterns in the given matchers to determine if a redirect action is required.
  /// If it is, a redirect url will be returned provided we can extract it from the url
  func redirectURL(for matchers: inout [DebouncingResourceDownloader.Matcher]) -> URL? {
    // Find our matcher
    guard let matcherIndex = matchers.firstIndex(where: { matcher in
      // Is not in the excludes list (this should be shorter so we check it first)
      // and is in the include list
      return !matcher.exclude.contains(where: { self.matches(pattern: $0) })
      && matcher.include.contains(where: { self.matches(pattern: $0) })
    }) else { return nil }

    // Lets get a reference.
    // We take the matcher via an index so we update our parent list with the actions as they are lazy
    let matcher = matchers[matcherIndex]
    let actions = matchers[matcherIndex].actions

    // For now we only support redirecting so it makes sense to check this right away
    // No point in trying to decode anything if we don't have this action
    guard actions.contains(.redirect) else {
      return nil
    }

    // Extract the redirect URL
    let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    guard var queryParamValue = components?.queryItems?.first(where: { $0.name == matcher.param })?.value else {
      return nil
    }

    if actions.contains(.base64) {
      // We need to base64 decode the url
      guard let data = Data(base64Encoded: queryParamValue),
            let decodedString = String(data: data, encoding: .utf8)
      else {
        return nil
      }

      queryParamValue = decodedString
    }

    return URL(string: queryParamValue)
  }
}
