// FileTests.swift
//
// The MIT License (MIT)
//
// Copyright (c) 2015 Zewo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
import File

class FileTests: XCTestCase {
    func testReadWrite() {
        do {
            let file = try File(path: "/tmp/zewo-test-file", mode: .truncateReadWrite)
            try file.write("abc")
            XCTAssert(try file.tell() == 3)
            try file.seek(0)
            var data = try file.read(length: 3)
            XCTAssert(data == "abc".data)
            XCTAssert(!file.eof)
            data = try file.read(length: 3)
            XCTAssert(data.count == 0)
            XCTAssert(file.eof)
            try file.seek(0)
            XCTAssert(!file.eof)
            try file.seek(3)
            XCTAssert(!file.eof)
            data = try file.read(length: 6)
            XCTAssert(data.count == 0)
            XCTAssert(file.eof)
        } catch {
            XCTFail()
        }
    }

    func testReadAllFile() {
        do {
            let file = try File(path: "/tmp/zewo-test-file", mode: .truncateReadWrite)
            let word = "hello"
            try file.write(word)
            try file.seek(0)
            let data = try file.read()
            XCTAssert(data.count == word.utf8.count)
        } catch {
            XCTFail()
        }
    }

    func testFileSize() {
        do {
            let file = try File(path: "/tmp/zewo-test-file", mode: .TruncateReadWrite)
            try file.write("hello")
            XCTAssert(file.length == 5)
            try file.write(" world")
            XCTAssert(file.length == 11)
        } catch {
            XCTFail()
        }
    }

//    func testFifo() {
//        do {
//            let readFile = try File(path: "/tmp/fifo")
//            let writeFile = try File(path: "/tmp/fifo", mode: .TruncateWrite)
//            let word = "hello"
//            after(3 * seconds) {
//                try! writeFile.write(word)
//            }
//
//            let data = try readFile.read(length: word.utf8.count)
//            print(data)
//        } catch {
//            print(error)
//            XCTFail()
//        }
//    }

    func testZero() {
        do {
            let file = try File(path: "/dev/zero")
            let count = 4096
            let length = 256

            for _ in 0 ..< count {
                let data = try file.read(length: length)
                XCTAssert(data.count == length)
            }
        } catch {
            XCTFail()
        }
    }

    func testRandom() {
        do {
            let file = try File(path: "/dev/random")
            let count = 4096
            let length = 256

            for _ in 0 ..< count {
                let data = try file.read(length: length)
                XCTAssert(data.count == length)
            }
        } catch {
            XCTFail()
        }
    }
}
