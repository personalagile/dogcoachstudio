import UIKit
import Testing
@testable import DogCoachStudio

@Suite("Dog photo storage")
struct DogPhotoStoreTests {
    @Test("Photo data survives after save and can be removed")
    func roundTrip() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let data = renderer.jpegData(withCompressionQuality: 1) { context in
            UIColor.systemOrange.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let id = try DogPhotoStore.save(data)

        #expect(DogPhotoStore.contains(id))
        #expect(UIImage(contentsOfFile: DogPhotoStore.url(for: id).path()) != nil)
        DogPhotoStore.remove(id)
        #expect(!DogPhotoStore.contains(id))
    }
}
