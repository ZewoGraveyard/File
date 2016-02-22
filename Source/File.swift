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

public var standardInputStream = try! File(fileDescriptor: STDIN_FILENO)
public var standardOutputStream = try! File(fileDescriptor: STDOUT_FILENO)
public var standardErrorStream = try! File(fileDescriptor: STDERR_FILENO)

public final class File {
	public enum Mode {
		case Read
        case CreateWrite
		case TruncateWrite
		case AppendWrite
		case ReadWrite
        case CreateReadWrite
		case TruncateReadWrite
		case AppendReadWrite

        var value: Int32 {
            switch self {
            case .Read: return O_RDONLY
            case .CreateWrite: return (O_WRONLY | O_CREAT | O_EXCL)
            case .TruncateWrite: return (O_WRONLY | O_CREAT | O_TRUNC)
            case .AppendWrite: return (O_WRONLY | O_CREAT | O_APPEND)
            case .ReadWrite: return (O_RDWR)
            case .CreateReadWrite: return (O_RDWR | O_CREAT | O_EXCL)
            case .TruncateReadWrite: return (O_RDWR | O_CREAT | O_TRUNC)
            case .AppendReadWrite: return (O_RDWR | O_CREAT | O_APPEND)
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

	public convenience init(path: String, mode: Mode = .Read) throws {
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

    public func write(data: Data, flush: Bool = true, deadline: Deadline = never) throws {
        try assertNotClosed()

        let bytesProcessed = data.withUnsafeBufferPointer {
            filewrite(file, $0.baseAddress, $0.count, deadline)
        }

        try FileError.assertNoSendErrorWithData(data, bytesProcessed: bytesProcessed)

        if flush {
            try self.flush(deadline)
        }
	}

    public func read(length length: Int, deadline: Deadline = never) throws -> Data {
        try assertNotClosed()

        var data = Data.bufferWithSize(length)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            fileread(file, $0.baseAddress, $0.count, deadline)
        }

        try FileError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return data.prefix(bytesProcessed)
    }

    public func read(lowWaterMark lowWaterMark: Int, highWaterMark: Int, deadline: Deadline = never) throws -> Data {
        try assertNotClosed()

        var data = Data.bufferWithSize(highWaterMark)
        let bytesProcessed = data.withUnsafeMutableBufferPointer {
            filereadlh(file, $0.baseAddress, lowWaterMark, highWaterMark, deadline)
        }

        try FileError.assertNoReceiveErrorWithData(data, bytesProcessed: bytesProcessed)
        return data.prefix(bytesProcessed)
    }

    public func read(deadline deadline: Deadline = never) throws -> Data {
        var data = Data()

        while true {
            data += try read(length: 256, deadline: deadline)

            if eof {
                break
            }
        }

        return data
    }

    public func flush(deadline: Deadline = never) throws {
        try assertNotClosed()
        fileflush(file, deadline)
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
    public func write(convertible: DataConvertible, flush: Bool = true, deadline: Deadline = never) throws {
        try write(convertible.data, flush: flush, deadline: deadline)
    }
}

extension File {
    public static func workingDirectory() throws -> String {
        var buffer = String.bufferWithSize(Int(MAXNAMLEN))
        errno = 0
        let workingDirectory = getcwd(&buffer, buffer.count)
        try FileError.assertNoError()
        return String.fromCString(workingDirectory)!
    }

    public static func contentsOfDirectoryAt(path: String) throws -> [String] {
        var contents: [String] = []

        let dir = opendir(path)

        if dir == nil {
            throw FileError.Unknown(description: "Could not open directory at \(path)")
        }

        defer {
            closedir(dir)
        }

        let excludeNames = [".", ".."]

        var entry: UnsafeMutablePointer<dirent> = readdir(dir)

        while entry != nil {
            if let entryName = withUnsafePointer(&entry.memory.d_name, { (ptr) -> String? in
                let int8Ptr = unsafeBitCast(ptr, UnsafePointer<Int8>.self)
                return String.fromCString(int8Ptr)
            }) {

                // TODO: `entryName` should be limited in length to `entry.memory.d_namlen`.
                if !excludeNames.contains(entryName) {
                    contents.append(entryName)
                }
            }

            entry = readdir(dir)
        }

        return contents
    }

    public static func fileExistsAt(path: String) -> (fileExists: Bool, isDirectory: Bool) {
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

    public static func createDirectoryAt(path: String, withIntermediateDirectories createIntermediates: Bool = false) throws {
        if createIntermediates {
            let (fileExists, isDirectory) = fileExistsAt(path)
            if fileExists {
                let parent = path.dropLastPathComponent

                if fileExistsAt(path).fileExists {
                    try createDirectoryAt(parent, withIntermediateDirectories: true)
                }
                mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
                try FileError.assertNoError()
            } else if isDirectory {
                return
            } else {
                throw FileError.FileExists(description: "File exists")
            }
        } else {
            mkdir(path, S_IRWXU | S_IRWXG | S_IRWXO)
            try FileError.assertNoError()
        }
    }

    public static func removeItemAt(path: String) throws {
        if rmdir(path) == 0 {
            return
        } else if errno == ENOTDIR {
            unlink(path)
        }
        try FileError.assertNoError()
    }
}
