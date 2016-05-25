// File.swift
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

import CLibvenice
@_exported import Venice
@_exported import String
@_exported import POSIX

public enum FileError: ErrorProtocol {
    case failedToSendCompletely(remaining: Data)
    case failedToReceiveCompletely(received: Data)
}

extension FileError: CustomStringConvertible {
    public var description: String {
        switch self {
        case failedToSendCompletely: return "Failed to send completely"
        case failedToReceiveCompletely: return "Failed to receive completely"
        }
    }
}

public final class File {
	public enum Mode {
		case read
        case createWrite
		case truncateWrite
		case appendWrite
		case readWrite
        case createReadWrite
		case truncateReadWrite
		case appendReadWrite

        var value: Int32 {
            switch self {
            case .read: return O_RDONLY
            case .createWrite: return (O_WRONLY | O_CREAT | O_EXCL)
            case .truncateWrite: return (O_WRONLY | O_CREAT | O_TRUNC)
            case .appendWrite: return (O_WRONLY | O_CREAT | O_APPEND)
            case .readWrite: return (O_RDWR)
            case .createReadWrite: return (O_RDWR | O_CREAT | O_EXCL)
            case .truncateReadWrite: return (O_RDWR | O_CREAT | O_TRUNC)
            case .appendReadWrite: return (O_RDWR | O_CREAT | O_APPEND)
            }
        }
	}

    private var file: mfile?
    public private(set) var closed = false
    public private(set) var path: String? = nil

    public func tell() throws -> Int {
        let position = Int(filetell(file))
        try ensureLastOperationSucceeded()
        return position
    }

    public func seek(position: Int) throws -> Int {
        let position = Int(fileseek(file, off_t(position)))
        try ensureLastOperationSucceeded()
        return position
    }

//   public var length: Int {
//       return Int(filesize(self.file))
//   }

    public var eof: Bool {
        return fileeof(file) != 0
    }

    public lazy var fileExtension: String? = {
        guard let path = self.path else {
            return nil
        }

        guard let fileExtension = path.split(separator: ".").last else {
            return nil
        }

        if fileExtension.split(separator: "/").count > 1 {
            return nil
        }

        return fileExtension
    }()

    init(file: mfile) {
        self.file = file
    }

	public convenience init(path: String, mode: Mode = .read) throws {
        let file = fileopen(path, mode.value, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        try ensureLastOperationSucceeded()
        self.init(file: file!)
        self.path = path
	}

    public convenience init(fileDescriptor: FileDescriptor) throws {
        let file = fileattach(fileDescriptor)
        try ensureLastOperationSucceeded()
        self.init(file: file!)
    }

	deinit {
        if let file = file where !closed {
            fileclose(file)
        }
	}
}

extension File {
    public func write(_ data: Data, flushing flush: Bool = true, timingOut deadline: Double = .never) throws {
        try ensureFileIsOpen()

        let remaining = data.withUnsafeBufferPointer {
            filewrite(file, $0.baseAddress, $0.count, deadline.int64milliseconds)
        }

        do {
            try ensureLastOperationSucceeded()
        } catch {
            throw FileError.failedToSendCompletely(remaining: Data(data.suffix(remaining)))
        }

        if flush {
            try self.flush(timingOut: deadline)
        }
	}

    public func read(upTo byteCount: Int, timingOut deadline: Double = .never) throws -> Data {
        try ensureFileIsOpen()

        var data = Data.buffer(with: byteCount)
        let received = data.withUnsafeMutableBufferPointer {
            filereadlh(file, $0.baseAddress, 1, $0.count, deadline.int64milliseconds)
        }

        let receivedData = Data(data.prefix(received))

        do {
            try ensureLastOperationSucceeded()
        } catch {
            throw FileError.failedToReceiveCompletely(received: receivedData)
        }

        return receivedData
    }

    public func read(_ byteCount: Int, timingOut deadline: Double = .never) throws -> Data {
        try ensureFileIsOpen()

        var data = Data.buffer(with: byteCount)
        let received = data.withUnsafeMutableBufferPointer {
            fileread(file, $0.baseAddress, $0.count, deadline.int64milliseconds)
        }

        let receivedData = Data(data.prefix(received))

        do {
            try ensureLastOperationSucceeded()
        } catch {
            throw FileError.failedToReceiveCompletely(received: receivedData)
        }

        return receivedData
    }

    public func readAllBytes(timingOut deadline: Double = .never) throws -> Data {
        var data = Data()

        while true {
            data += try read(upTo: 2048, timingOut: deadline)

            if eof {
                break
            }
        }

        return data
    }

    public func flush(timingOut deadline: Double = .never) throws {
        try ensureFileIsOpen()
        fileflush(file, deadline.int64milliseconds)
        try ensureLastOperationSucceeded()
    }

    public func close() throws {
        guard !closed else { throw ClosableError.alreadyClosed }
        closed = true
        fileclose(file)
    }

    private func ensureFileIsOpen() throws {
        if closed {
            throw StreamError.closedStream(data: [])
        }
    }
}

extension File {
    public var stream: Stream {
        return FileStream(file: self)
    }
}

extension File {
    public func write(_ convertible: DataConvertible, flushing flush: Bool = true, deadline: Double = .never) throws {
        try write(convertible.data, flushing: flush, timingOut: deadline)
    }
}

extension File {
    public static func workingDirectory() throws -> String {
        var buffer = String.buffer(size: Int(MAXNAMLEN))
        errno = 0
        let workingDirectory = getcwd(&buffer, buffer.count)
        try ensureLastOperationSucceeded()
        return String(cString: workingDirectory!)
    }

    public static func contentsOfDirectory(at path: String) throws -> [String] {
        var contents: [String] = []

        let dir = opendir(path)
        try ensureLastOperationSucceeded()

        defer {
            closedir(dir!)
        }

        let excludeNames = [".", ".."]

        while let file = readdir(dir!) {

            let entry: UnsafeMutablePointer<dirent> = file

            if let entryName = withUnsafeMutablePointer(&entry.pointee.d_name, { (ptr) -> String? in
                let entryPointer = unsafeBitCast(ptr, to: UnsafePointer<CChar>.self)
                return String(validatingUTF8: entryPointer)
            }) {
                if !excludeNames.contains(entryName) {
                    contents.append(entryName)
                }
            }
        }

        return contents
    }

    public static func exists(at path: String) -> (exists: Bool, isDirectory: Bool) {
        var s = stat()
        var isDirectory = false

        if lstat(path, &s) >= 0 {
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if stat(path, &s) >= 0 {
                    isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
                } else {
                    return (false, isDirectory)
                }
            } else {
                isDirectory = (s.st_mode & S_IFMT) == S_IFDIR
            }

            // don't chase the link for this magic case -- we might be /Net/foo
            // which is a symlink to /private/Net/foo which is not yet mounted...
            if (s.st_mode & S_IFMT) == S_IFLNK {
                if (s.st_mode & S_ISVTX) == S_ISVTX {
                    return (true, isDirectory)
                }
                // chase the link; too bad if it is a slink to /Net/foo
                stat(path, &s) >= 0
            }
        } else {
            return (false, isDirectory)
        }
        return (true, isDirectory)
    }

    public static func createDirectory(at path: String, withIntermediateDirectories createIntermediates: Bool = false) throws {
        if createIntermediates {
            let (fileExists, isDirectory) = exists(at: path)
            if fileExists {
                let parent = path.dropLastPathComponent

                if exists(at: path).exists {
                    try createDirectory(at: parent, withIntermediateDirectories: true)
                }
                mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
                try ensureLastOperationSucceeded()
            } else if isDirectory {
                return
            } else {
                throw SystemError.fileExists
            }
        } else {
            mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
            try ensureLastOperationSucceeded()
        }
    }

    public static func removeItem(at path: String) throws {
        if rmdir(path) == 0 {
            return
        } else if errno == ENOTDIR {
            unlink(path)
        }
        try ensureLastOperationSucceeded()
    }
}
