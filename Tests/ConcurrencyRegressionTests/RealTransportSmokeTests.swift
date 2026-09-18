import XCTest
import SwiftPhoenixClient

/// Basic regression check that `Socket` + the real `URLSessionTransport` still behave correctly after locking changes.

final class RealTransportSmokeTests: XCTestCase {

    func testConnectToRefusedPortReportsErrorThenCanDisconnectCleanly() {
        let socket = Socket("ws://127.0.0.1:1/socket")

        let errorExpectation = expectation(description: "received a connection error")
        socket.onError { _, _ in
            errorExpectation.fulfill()
        }

        socket.connect()
        wait(for: [errorExpectation], timeout: 10)

        socket.disconnect()
        XCTAssertFalse(socket.isConnected)
    }

    func testRapidRealConnectDisconnectCyclesDontCrash() {
        let expectation = expectation(description: "workers finished")
        let workers = 16
        expectation.expectedFulfillmentCount = workers

        for _ in 0..<workers {
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<2000 {
                    autoreleasepool {
                        let socket = Socket("ws://127.0.0.1:1/socket")
                        socket.connect()
                        socket.disconnect()
                    }
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 180)
    }
}
