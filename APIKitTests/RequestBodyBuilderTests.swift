import Foundation
import APIKit
import Result
import XCTest

class RequestBodyBuilderTests: XCTestCase {
    func testJSONHeader() {
        let builder = RequestBodyBuilder.JSON(writingOptions: NSJSONWritingOptions(rawValue: 0))
        XCTAssert(builder.contentTypeHeader == "application/json")
    }
    
    func testJSONSuccess() {
        let object = ["foo": 1, "bar": 2, "baz": 3]
        let builder = RequestBodyBuilder.JSON(writingOptions: NSJSONWritingOptions(rawValue: 0))

        switch builder.buildBodyFromObject(object) {
        case .Success(let data):
            let dictionary = try! NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0)) as? [String: Int]
            XCTAssert(dictionary?["foo"] == 1)
            XCTAssert(dictionary?["bar"] == 2)
            XCTAssert(dictionary?["baz"] == 3)

        case .Failure:
            XCTFail()
        }
    }
    
    func testJSONFailure() {
        let object = NSObject()
        let builder = RequestBodyBuilder.JSON(writingOptions: NSJSONWritingOptions(rawValue: 0))

        switch builder.buildBodyFromObject(object) {
        case .Success:
            XCTFail()
            
        case .Failure(let error):
            XCTAssert(error.domain == APIKitRequestBodyBuidlerErrorDomain)
            XCTAssert(error.code == 0)
        }
    }
    
    func testURLHeader() {
        let builder = RequestBodyBuilder.URL(encoding: NSUTF8StringEncoding)
        XCTAssert(builder.contentTypeHeader == "application/x-www-form-urlencoded")
    }
    
    func testURLSuccess() {
        let object = ["foo": 1, "bar": 2, "baz": 3]
        let builder = RequestBodyBuilder.URL(encoding: NSUTF8StringEncoding)

        switch builder.buildBodyFromObject(object) {
        case .Success(let data):
            let dictionary =  URLEncodedSerialization.objectFromData(data, encoding: NSUTF8StringEncoding, error: nil) as? [String: String]
            XCTAssert(dictionary?["foo"] == "1")
            XCTAssert(dictionary?["bar"] == "2")
            XCTAssert(dictionary?["baz"] == "3")

        case .Failure:
            XCTFail()
        }
    }
    
    func testCustomHeader() {
        let builder = RequestBodyBuilder.Custom(contentTypeHeader: "foo", buildBodyFromObject: { o in .success(o as! NSData) })
        XCTAssert(builder.contentTypeHeader == "foo")
    }
    
    func testCustomSuccess() {
        let string = "foo"
        let expectedData = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
        let builder = RequestBodyBuilder.Custom(contentTypeHeader: "", buildBodyFromObject: { object in
            return .success(expectedData)
        })

        switch builder.buildBodyFromObject(string) {
        case .Success(let data):
            XCTAssert(data == expectedData)

        case .Failure:
            XCTFail()
        }
    }

    func testCustomFailure() {
        let string = "foo"
        let expectedError = NSError(domain: "Foo", code: 1234, userInfo: nil)
        let builder = RequestBodyBuilder.Custom(contentTypeHeader: "", buildBodyFromObject: { object in
            return .failure(expectedError)
        })

        switch builder.buildBodyFromObject(string) {
        case .Success:
            XCTFail()

        case .Failure(let error):
            XCTAssert(error == expectedError)
        }
    }
}
