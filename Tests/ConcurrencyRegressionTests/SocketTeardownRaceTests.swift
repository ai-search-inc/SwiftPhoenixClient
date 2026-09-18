import XCTest
import SwiftPhoenixClient

enum TestError: Error {
    case stub
}

/// A fake `PhoenixTransport` that mirrors the one specific behavior implicated every
/// `connect()` schedules a background callback that fires shortly afterward and reports an
/// error.
///
/// `delegate` is not weak, that's what lets a `Socket` stay artificially alive via this 
/// transport's own reference to it until `teardown()` nils it out.
final class DelayedErrorTransport: PhoenixTransport {
    var readyState: PhoenixTransportReadyState = .closed
    var delegate: PhoenixTransportDelegate?

    func connect(with headers: [String: Any]) {
        readyState = .open

        DispatchQueue.global().async { [self] in
            delegate?.onError(error: TestError.stub, response: nil)
        }

        delegate?.onOpen(response: nil)
    }

    func disconnect(code: Int, reason: String?) {
        readyState = .closed
    }

    func send(data: Data) {}
}

/// Regression coverage for `Socket.onConnectionError` crashing with EXC_BAD_ACCESS when a
/// `Socket` is torn down.
///
///     swift test --filter ConcurrencyRegressionTests --sanitize=thread
///
final class SocketTeardownRaceTests: XCTestCase {

    func testRapidConnectDisconnectUnderConcurrencyDoesNotRace() {
        let iterationsPerWorker = 10000
        let concurrentWorkers = 16

        let expectation = expectation(description: "all workers finished")
        expectation.expectedFulfillmentCount = concurrentWorkers

        for _ in 0..<concurrentWorkers {
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<iterationsPerWorker {
                    autoreleasepool {
                        let socket = Socket(
                            endPoint: "ws://127.0.0.1:1/socket",
                            transport: { _ in DelayedErrorTransport() },
                            paramsClosure: nil
                        )
                        socket.connect()
                        // No delay: disconnect immediately.
                        socket.disconnect()
                        // `socket` goes out of scope here.
                    }
                }
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 120)
    }
}
