// Copyright 2022 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import XCTest
import Shared

class PatternMatcherTests: XCTestCase {
  func testPatternsMatching() throws {
    // Given:
    // patterns and test string
    let testString = "https://bar.foo.com/redirect.php?url=some-string"
    let patterns: [String] = [
      "https://bar.foo.com/redirect.php?url=some-string", // Exact string
      "https://???.foo.com/redirect.php?url=some-string", // With 3 letter wildcard
      "https://bar.foo.com/*",
      "****s://*", // needs at least 4 characters before 's://'
      "*://***.*", // needs at least 3 characters between '://' and '.'
      "*://*.foo.com/redirect.php?url=*",
      "*foo*", // 'foo' in the middle
      "**foo*", // 'foo' in the middle
      "*foo**", // 'foo' in the middle
      "**", // any characters with a size of 2 or more
      "*", // any characters with size of 1 or more
    ]

    // Then:
    // Patterns match
    for pattern in patterns {
      XCTAssertTrue(PatternMatcher.matches(
        pattern: pattern, in: testString))
    }

    // Given
    // A test string of `foo` and a pattern with 3 wildcards
    // Then
    // Enough characters in test string (need at least 3)
    XCTAssertFalse(PatternMatcher.matches(pattern: "foo", in: "***"))
  }

  func testPatternsNotMatching() throws {
    // Given:
    // patterns and test string
    let testString = "https://foo.bar.com/redirect.php?url=some-string"
    let patterns: [String] = [
      "https://foo.bar.com/redirect.php?url=some-string*", // trailing '*'
      "https://****.foo.com/redirect.php?url=some-string", // 4 '*'s
      "https://????.foo.com/redirect.php?url=some-string", // 4 letter wildcard
      "*****s://foo.bar*", // Need at least 5 characters at the start
      "foo*", // 'foo must be at the beginning with
      "foo**", // 'foo' must be the beginning with at least 2 following characters
      "*foo", // 'foo' must be at the end with at least 1 character before
      "**foo", // 'foo' must be at the end with at least 2 character before
      "*https://foo.bar.com/redirect.php?url=some-string" // has '*' in front
    ]

    // Then:
    // Pattern don't match
    for pattern in patterns {
      XCTAssertFalse(PatternMatcher.matches(pattern: pattern, in: testString))
    }

    // Given
    // A test string of `foo` and a pattern with 4 wildcards
    // Then
    // Not enough characters in test string (need at least 4)
    XCTAssertFalse(PatternMatcher.matches(pattern: "foo", in: "****"))
  }
}
