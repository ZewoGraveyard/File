// FileStream.swift
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

public var standardInputStream = try! FileStream(file: File(fileDescriptor: STDIN_FILENO))
public var standardOutputStream = try! FileStream(file: File(fileDescriptor: STDOUT_FILENO))
public var standardErrorStream = try! FileStream(file: File(fileDescriptor: STDERR_FILENO))

public final class FileStream: Stream {
    private let file: File
    public let metadata: [String: Any] = [:]

    public var lowWaterMark: Int
    public var highWaterMark: Int

    public var closed: Bool {
        return file.closed
    }

    public init(file: File, lowWaterMark: Int = 1, highWaterMark: Int = 4096) {
        self.file = file
        self.lowWaterMark = lowWaterMark
        self.highWaterMark = highWaterMark
    }

    public func receive(upTo byteCount: Int, timingOut deadline: Double = .never) throws -> Data {
        try assertNotClosed()
        do {
            if file.eof {
                file.close()
                return []
            } else {
                return try file.read(lowWaterMark: lowWaterMark, highWaterMark: min(byteCount, highWaterMark), timingOut: deadline)
            }
        } catch FileError.connectionResetByPeer(_, let data) {
            throw StreamError.closedStream(data: data)
        } catch FileError.brokenPipe(_, let data) {
            throw StreamError.closedStream(data: data)
        }
    }
    
    public func receive(timingOut deadline: Double = .never) throws -> Data {
        return try receive(upTo: highWaterMark, timingOut: deadline)
    }

    public func send(data: Data, timingOut deadline: Double = .never) throws {
        try assertNotClosed()
        do {
            try file.write(data, flush: false, timingOut: deadline)
        } catch FileError.connectionResetByPeer(_, let data) {
            throw StreamError.closedStream(data: data)
        } catch FileError.brokenPipe(_, let data) {
            throw StreamError.closedStream(data: data)
        }
    }

    public func flush(timingOut deadline: Double = .never) throws {
        try assertNotClosed()
        do {
            try file.flush(timingOut: deadline)
        } catch FileError.connectionResetByPeer(_, let data) {
            throw StreamError.closedStream(data: data)
        } catch FileError.brokenPipe(_, let data) {
            throw StreamError.closedStream(data: data)
        }
    }

    public func close() -> Bool {
        return file.close()
    }

    private func assertNotClosed() throws {
        if closed {
            throw StreamError.closedStream(data: [])
        }
    }
}