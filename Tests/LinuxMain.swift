#if os(Linux)

import XCTest
@testable import FileTestSuite

XCTMain([
    testCase(FileTests.allTests)
])

#endif
