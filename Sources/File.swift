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
@_exported import Data
@_exported import String

public final class File: Stream {
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

    private var file: mfile
    public private(set) var closed = false
    public private(set) var path: String? = nil
    
    public func tell() throws -> Int {
        let position = Int(filetell(file))
        try FileError.assertNoError()
        return position
    }

    public func seek(position: Int) throws -> Int {
        let position = Int(fileseek(file, off_t(position)))
        try FileError.assertNoError()
        return position
    }

    public var eof: Bool {
        return fileeof(file) != 0
    }

    public lazy var fileExtension: String? = {
        guard let path = self.path else {
            return nil
        }

        guard let fileExtension = path.split(".").last else {
            return nil
        }

        if fileExtension.split("/").count > 1 {
            return nil
        }

        return fileExtension
    }()

    init(file: mfile) throws {
        self.file = file
        try FileError.assertNoError()
    }

	public convenience init(path: String, mode: Mode = .read) throws {
        try self.init(file: fileopen(path, mode.value, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH))
        self.path = path
	}

    public convenience init(fileDescriptor: FileDescriptor) throws {
        try self.init(file: fileattach(fileDescriptor))
    }

	deinit {
        if !closed && file != nil {
            fileclose(file)
        }
	}
    
}

extension File {
    public func write(data: Data, flush: Bool = true, timingOut deadline: Double = .never) throws {
        try assertNotClosed()

        let bytesProcessed = data.withUnsafeBufferPointer {
            filewrite(file, $0.baseAddress, $0.count, deadline.int64milliseconds)
        }

        try FileError.assertNoSendErrorWithData(data, bytesProcessed: bytesProcessed)

        if flush {
            try self.flush(timingOut: deadline)
        }
	}

    public func read(length length: Int, timingOut deadline: Double = .never) throws -> Data {
        try assertNotClosed()

        var data = Data.buffer(with: length)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            fileread(file, $0.baseAddress, $0.count, deadline.int64milliseconds)
        }

        try FileError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return Data(data.prefix(bytesProcessed))
    }

    public func read(lowWaterMark lowWaterMark: Int, highWaterMark: Int, timingOut deadline: Double = .never) throws -> Data {
        try assertNotClosed()

        var data = Data.buffer(with: highWaterMark)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            filereadlh(file, $0.baseAddress, lowWaterMark, highWaterMark, deadline.int64milliseconds)
        }

        try FileError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return Data(data.prefix(bytesProcessed))
    }

    public func read(deadline deadline: Double = .never) throws -> Data {
        var data = Data()

        while true {
            data += try read(length: 256, timingOut: deadline)

            if eof {
                break
            }
        }

        return data
    }

    public func flush(timingOut deadline: Double = .never) throws {
        try assertNotClosed()
        fileflush(file, deadline.int64milliseconds)
        try FileError.assertNoError()
    }

    public func attach(fileDescriptor: FileDescriptor) throws {
        if !closed {
            close()
        }

        file = fileattach(fileDescriptor)
        try FileError.assertNoError()
        closed = false
    }

    public func detach() throws -> FileDescriptor {
        try assertNotClosed()
        closed = true
        return filedetach(file)
    }

    public func close() -> Bool {
        if closed {
            return false
        }

        closed = true
        fileclose(file)
        return true
    }

    func assertNotClosed() throws {
        if closed {
            throw FileError.closedFileError
        }
    }
}

extension File {
    public func send(data: Data, timingOut deadline: Double) throws {
        try write(data, flush: true, timingOut: deadline)
    }
    
    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        return try read(length: byteCount, timingOut: deadline)
    }
    
}

extension File {
    public func write(convertible: DataConvertible, flush: Bool = true, deadline: Double = .never) throws {
        try write(convertible.data, flush: flush, timingOut: deadline)
    }
}

extension File {
    public static func workingDirectory() throws -> String {
        var buffer = String.buffer(size: Int(MAXNAMLEN))
        errno = 0
        let workingDirectory = getcwd(&buffer, buffer.count)
        try FileError.assertNoError()
        return String(cString: workingDirectory)
    }

    public static func contentsOfDirectoryAt(path: String) throws -> [String] {
        var contents: [String] = []

        let dir = opendir(path)

        if dir == nil {
            throw FileError.unknown(description: "Could not open directory at \(path)")
        }

        defer {
            closedir(dir)
        }

        let excludeNames = [".", ".."]

        var entry: UnsafeMutablePointer<dirent> = readdir(dir)

        while entry != nil {
            if let entryName = withUnsafePointer(&entry.pointee.d_name, { (ptr) -> String? in
                let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
                return String(validatingUTF8: int8Ptr)
            }) {

                // TODO: `entryName` should be limited in length to `entry.pointee.d_namlen`.
                if !excludeNames.contains(entryName) {
                    contents.append(entryName)
                }
            }

            entry = readdir(dir)
        }

        return contents
    }

    public static func fileExists(at path: String) -> (fileExists: Bool, isDirectory: Bool) {
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
            let (exists, isDirectory) = fileExists(at: path)
            if exists {
                let parent = path.dropLastPathComponent

                if fileExists(at: path).fileExists {
                    try createDirectory(at: parent, withIntermediateDirectories: true)
                }
                mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
                try FileError.assertNoError()
            } else if isDirectory {
                return
            } else {
                throw FileError.fileExists(description: "File exists")
            }
        } else {
            mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
            try FileError.assertNoError()
        }
    }

    public static func removeItem(at path: String) throws {
        if rmdir(path) == 0 {
            return
        } else if errno == ENOTDIR {
            unlink(path)
        }
        try FileError.assertNoError()
    }
}

private extension Double {
    
    var int64milliseconds: Int64 {
        return Int64(self * 1000)
    }
    
}

