import Foundation

enum CodableAttribute {
    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? JSONDecoder().decode(type, from: data)
    }

    static func encode<Value: Encodable>(_ value: Value) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }
}

