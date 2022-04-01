// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation

/// An object that does pattern matching with `'*'`or `'?'` wildcards.
///
/// Examples:
/// ```
/// "*://*.foo.com/redirect.php?url=*",
/// "*foo",
/// "foo*",
/// "*foo*",
/// "*",
/// ""
/// ```
final public class PatternMatcher {
  /// Checks if a string matches the given pattern
  ///
  /// For example
  /// `*://*.leechall.com/redirect.php?url=*`
  /// should match
  /// `https://test.leechall.com/redirect.php?url=blah`
  public static func matches(pattern: String, in value: String) -> Bool {
    var currentPatternIndex = 0
    var currentValueIndex = 0
    var numberOfWildcards = 0

    while currentPatternIndex < pattern.count, currentValueIndex < value.count {
      let patternChar = pattern[pattern.index(pattern.startIndex, offsetBy: currentPatternIndex)]

      switch patternChar {
      case "?":
        // Anything goes, we can skip forward for both string
        currentPatternIndex += 1
        currentValueIndex += 1
        
      case "*":
        numberOfWildcards += 1

        if currentPatternIndex + 1 < pattern.count {
          // We found a wild card that's not in the end of our pattern
          // We need to move our currentValueIndex forward until the end of the wildcard and beyond
          // First we find a forward string to look for.
          // Then we search forward in our urlString to see if it matches
          // If all is good, we then update the current indexes of both the pattern and url string
          // To go beyond this matched pattern
          let endIndex = getNextIndex(for: pattern, to: "*", startingAt: currentPatternIndex + 1) ?? pattern.count
          let patternSubstringStart = pattern.index(pattern.startIndex, offsetBy: currentPatternIndex + 1)
          let patternSubstringEnd = pattern.index(pattern.startIndex, offsetBy: endIndex)
          let patternSubstring = pattern[patternSubstringStart..<patternSubstringEnd]

          if patternSubstring.isEmpty {
            // We basically have `*` right after our `*`.
            // `numberOfWildcards` will be updated on the next interation (above)
            currentPatternIndex += 1
            continue
          } else if let index = getNextIndex(for: value, to: String(patternSubstring), startingAt: currentValueIndex) {
            // We found a matching string
            // First make sure its the right length (i.e. number of `*`s found or more)
            guard index - currentValueIndex >= numberOfWildcards else {
              return false
            }

            currentValueIndex = index + patternSubstring.count
            numberOfWildcards = 0
          } else {
            // We didn't find a matching string. Pattern does not match
            return false
          }

          currentPatternIndex = endIndex
        } else {
          // If our pattern is at the end, we allow all trailing strings to match.
          // Which they have to be or we would have been out of the loop
          return value.count - currentValueIndex >= numberOfWildcards
        }

      default:
        // We do a simple char-by-char comparison
        let urlChar = value[value.index(value.startIndex, offsetBy: currentValueIndex)]

        guard urlChar == patternChar else {
          return false
        }

        currentPatternIndex += 1
        currentValueIndex += 1
      }
    }

    // If we got to this point we went through the entire pattern and value and found no mistakes
    return currentValueIndex == value.count && currentPatternIndex == pattern.count
  }

  private static func getNextIndex(for string: String, to matcher: String, startingAt startingIndex: Int) -> Int? {
    guard !matcher.isEmpty else {
      // Handles matcher situations such as `**`
      return startingIndex
    }

    var currentIndex = startingIndex

    while currentIndex <= string.count {
      let endCount = currentIndex + matcher.count

      guard endCount <= string.count else {
        // We reached the end of our string.
        // We don't have enough characters to represent this value
        return nil
      }

      let currentStringIndex = string.index(string.startIndex, offsetBy: currentIndex)
      let endStringIndex = string.index(currentStringIndex, offsetBy: matcher.count)
      let forwardString = string[currentStringIndex..<endStringIndex]

      if matcher == forwardString {
        return currentIndex
      }

      currentIndex += 1
    }

    return nil
  }
}

public extension String {
  func matches(pattern: String) -> Bool {
    return PatternMatcher.matches(pattern: pattern, in: self)
  }
}

public extension URL {
  func matches(pattern: String) -> Bool {
    return PatternMatcher.matches(pattern: pattern, in: absoluteString)
  }
}
