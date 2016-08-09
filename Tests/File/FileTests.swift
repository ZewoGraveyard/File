import XCTest
import File

class FileTests: XCTestCase {
    func testReadWrite() {
        do {
            let file = try File(path: "/tmp/zewo-test-file", mode: .truncateReadWrite)
            try file.write("abc")
            XCTAssert(try file.tell() == 3)
            try file.seek(position: 0)
            var data = try file.read(3)
            XCTAssert(data == "abc".data)
            XCTAssert(!file.eof)
            data = try file.read(3)
            XCTAssert(data.count == 0)
            XCTAssert(file.eof)
            try file.seek(position: 0)
            XCTAssert(!file.eof)
            try file.seek(position: 3)
            XCTAssert(!file.eof)
            data = try file.read(6)
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
            try file.seek(position: 0)
            let data = try file.readAllBytes()
            XCTAssert(data.count == word.utf8.count)
        } catch {
            XCTFail()
        }
    }

//    func testFileSize() {
//        do {
//            let file = try File(path: "/tmp/zewo-test-file", mode: .truncateReadWrite)
//            try file.write("hello")
//            XCTAssert(file.length == 5)
//            try file.write(" world")
//            XCTAssert(file.length == 11)
//        } catch {
//            XCTFail()
//        }
//    }

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
                let data = try file.read(length)
                XCTAssert(data.count == length)
            }
        } catch {
            XCTFail()
        }
    }

    #if os(OSX)
        func testRandom() {
            do {
                let file = try File(path: "/dev/random")
                let count = 4096
                let length = 256

                for _ in 0 ..< count {
                    let data = try file.read(length)
                    XCTAssert(data.count == length)
                }
            } catch {
                XCTFail()
            }
        }
    #endif
    
	
    func testStaticMethods() throws {
        let filePath = "/tmp/zewo-test-file"
        let baseDirectoryPath = "/tmp/zewo"
        let directoryPath = baseDirectoryPath + "/test/dir/"
        
        let file = try File(path: filePath, mode: .truncateWrite)
        
        XCTAssertTrue(File.exists(at: filePath).exists)
        XCTAssertFalse(File.exists(at: filePath).isDirectory)
        
        let word = "hello"
        try file.write(word)
        try file.close()
        try File.removeItem(at: filePath)
        
        XCTAssertThrowsError(try File.removeItem(at: filePath))
        XCTAssertFalse(File.exists(at: filePath).exists)
        XCTAssertFalse(File.exists(at: filePath).isDirectory)

        try File.createDirectory(at: baseDirectoryPath)
        
        XCTAssertThrowsError(try File.createDirectory(at: baseDirectoryPath))
        XCTAssertEqual(try File.contentsOfDirectory(at: baseDirectoryPath), [])
        XCTAssertTrue(File.exists(at: baseDirectoryPath).exists)
        XCTAssertTrue(File.exists(at: baseDirectoryPath).isDirectory)
        
        try File.removeItem(at: baseDirectoryPath)
        
        XCTAssertThrowsError(try File.removeItem(at: baseDirectoryPath))
        XCTAssertThrowsError(try File.contentsOfDirectory(
            at: baseDirectoryPath))
        XCTAssertFalse(File.exists(at: baseDirectoryPath).exists)
        XCTAssertFalse(File.exists(at: baseDirectoryPath).isDirectory)
        
        try File.createDirectory(at: directoryPath,
                                 withIntermediateDirectories: true)
        
        XCTAssertEqual(try File.contentsOfDirectory(at: baseDirectoryPath),
                       ["test"])
        XCTAssertTrue(File.exists(at: directoryPath).exists)
        XCTAssertTrue(File.exists(at: directoryPath).isDirectory)
        
        try File.removeItem(at: directoryPath)
        try File.removeItem(at: directoryPath.dropLastPathComponent)
        try File.removeItem(at: baseDirectoryPath)
        
        XCTAssertFalse(File.exists(at: baseDirectoryPath).exists)
        XCTAssertFalse(File.exists(at: baseDirectoryPath).isDirectory)
    }
	
}

extension FileTests {
    static var allTests : [(String, (FileTests) -> () throws -> Void)] {
        #if os(OSX)
        return [
            ("testReadWrite", testReadWrite),
            ("testReadAllFile", testReadAllFile),
            // ("testFileSize", testFileSize),
            ("testZero", testZero),
            ("testRandom", testRandom),
            ("testStaticMethods", testStaticMethods),
        ]
        #else
        return [
            ("testReadWrite", testReadWrite),
            ("testReadAllFile", testReadAllFile),
            // ("testFileSize", testFileSize),
            ("testZero", testZero),
            // ("testRandom", testRandom),
            ("testStaticMethods", testStaticMethods),
        ]
        #endif
    }
}
