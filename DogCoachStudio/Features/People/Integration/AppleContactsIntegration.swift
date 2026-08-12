import Contacts
@preconcurrency import ContactsUI
import SwiftUI

struct ImportedAppleContact: Equatable, Sendable {
    let displayName: String
    let email: String?
    let phone: String?
    let street: String?
    let postalCode: String?
    let city: String?
    let countryCode: String?

    var clientDraft: ClientDraft {
        ClientDraft(
            displayName: displayName,
            email: email,
            phone: phone,
            addressStreet: street,
            addressPostalCode: postalCode,
            addressCity: city,
            addressCountryCode: countryCode,
            privateNotes: nil
        )
    }
}

enum AppleContactsError: Error, Equatable, Sendable {
    case accessDenied
    case missingName
}

enum AppleContactsMapper {
    static func importedContact(from contact: CNContact) throws -> ImportedAppleContact {
        let displayName = CNContactFormatter.string(from: contact, style: .fullName)
            ?? contact.organizationName
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleContactsError.missingName
        }
        let address = contact.postalAddresses.first?.value
        return ImportedAppleContact(
            displayName: displayName,
            email: contact.emailAddresses.first.map { String($0.value) },
            phone: contact.phoneNumbers.first?.value.stringValue,
            street: address?.street,
            postalCode: address?.postalCode,
            city: address?.city,
            countryCode: address?.isoCountryCode
        )
    }

    static func mutableContact(from client: ClientSummary) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = client.displayName
        if let email = client.email, !email.isEmpty {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }
        if let phone = client.phone, !phone.isEmpty {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))]
        }
        let address = CNMutablePostalAddress()
        address.street = client.addressStreet ?? ""
        address.postalCode = client.addressPostalCode ?? ""
        address.city = client.addressCity ?? ""
        address.isoCountryCode = client.addressCountryCode ?? ""
        if !address.street.isEmpty || !address.postalCode.isEmpty || !address.city.isEmpty {
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: address)]
        }
        return contact
    }
}

@MainActor
enum AppleContactsExporter {
    static func export(_ client: ClientSummary, store: CNContactStore = CNContactStore()) async throws {
        guard try await store.requestAccess(for: .contacts) else { throw AppleContactsError.accessDenied }
        let request = CNSaveRequest()
        request.add(AppleContactsMapper.mutableContact(from: client), toContainerWithIdentifier: nil)
        try store.execute(request)
    }
}

struct AppleContactPicker: UIViewControllerRepresentable {
    let onSelect: @MainActor (ImportedAppleContact) -> Void
    let onError: @MainActor (Error) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        let parent: AppleContactPicker

        init(parent: AppleContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            do { parent.onSelect(try AppleContactsMapper.importedContact(from: contact)) }
            catch { parent.onError(error) }
        }
    }
}
