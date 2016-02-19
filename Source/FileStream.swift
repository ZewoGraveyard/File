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

@_exported import Stream

public final class FileStream: StreamType {
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

    public func receive() throws -> Data {
        try assertNotClosed()
        do {
            if file.eof {
                file.close()
                return []
            } else {
                return try file.read(lowWaterMark: lowWaterMark, highWaterMark: highWaterMark)
            }
        } catch FileError.ConnectionResetByPeer(_, let data) {
            throw StreamError.ClosedStream(data: data)
        } catch FileError.BrokenPipe(_, let data) {
            throw StreamError.ClosedStream(data: data)
        }
    }

    public func send(data: Data) throws {
        try assertNotClosed()
        do {
            try file.write(data, flush: false)
        } catch FileError.ConnectionResetByPeer(_, let data) {
            throw StreamError.ClosedStream(data: data)
        } catch FileError.BrokenPipe(_, let data) {
            throw StreamError.ClosedStream(data: data)
        }
    }

    public func flush() throws {
        try assertNotClosed()
        do {
            try file.flush()
        } catch FileError.ConnectionResetByPeer(_, let data) {
            throw StreamError.ClosedStream(data: data)
        } catch FileError.BrokenPipe(_, let data) {
            throw StreamError.ClosedStream(data: data)
        }
    }

    public func close() -> Bool {
        return file.close()
    }

    private func assertNotClosed() throws {
        if closed {
            throw StreamError.ClosedStream(data: nil)
        }
    }
}