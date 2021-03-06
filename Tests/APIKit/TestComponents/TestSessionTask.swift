import Foundation
import APIKit

class TestSessionTask: SessionTaskType {
    
    var handler: (Data?, URLResponse?, Error?) -> Void
    var cancelled = false

    init(handler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.handler = handler
    }

    func resume() {

    }

    func cancel() {
        cancelled = true
    }
}
