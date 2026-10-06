import AVFoundation
import PhotosUI
import SwiftUI
import TatumTechKit

/// Creates or edits the user's Tatum Tech contact card. Name and email also update the profile.
struct ContactCardEditorView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var isLoading = true
    @State private var existing: ContactCard?
    @State private var form = CardFields()
    @State private var firstNameError: LocalizedStringKey?
    @State private var emailError: LocalizedStringKey?
    @State private var photoItem: PhotosPickerItem?
    @State private var newPhoto: UIImage?
    @State private var isCameraPresented = false
    @State private var isSaving = false
    @State private var toast: ToastMessage?

    private struct CardFields {
        var firstName = ""
        var lastName = ""
        var jobTitle = ""
        var company = ""
        var description = ""
        var website = ""
        var email = ""
        var phone = ""
        var alternateEmail = ""
        var linkedin = ""
        var twitter = ""
        var customLink = ""
        var calendly = ""
    }

    var body: some View {
        Group {
            if isLoading {
                Color.clear
            } else {
                ScrollView { fields }
                    .scrollDismissesKeyboard(.interactively)
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Tatum Tech Card")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraCapture { image in
                isCameraPresented = false
                if let image {
                    newPhoto = image
                } else {
                    toast = ToastMessage(text: "Photo capture cancelled")
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    newPhoto = image
                }
                photoItem = nil
            }
        }
        .task { await load() }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionTitle("Profile")
            HStack(spacing: Spacing.sm) {
                photo
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Choose photo")
                }
                .buttonStyle(.outlinedAction)
                .fixedSize()
                .accessibilityIdentifier("contactCard.choosePhoto")
                Button("Take photo", action: takePhoto)
                    .buttonStyle(.outlinedAction)
                    .fixedSize()
                    .accessibilityIdentifier("contactCard.takePhoto")
            }
            LabeledFormField(label: "First Name", text: $form.firstName, systemImage: "person.fill",
                             contentType: .givenName, errorMessage: firstNameError, identifier: "contactCard.firstName")
                .onChange(of: form.firstName) { firstNameError = nil }
            LabeledFormField(label: "Last Name", text: $form.lastName, systemImage: "person.fill", contentType: .familyName)
            LabeledFormField(label: "Job title", text: $form.jobTitle, systemImage: "person.fill", contentType: .jobTitle)
            LabeledFormField(label: "Company", text: $form.company, contentType: .organizationName)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Description")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.textSecondary)
                TextField("Description", text: $form.description, axis: .vertical)
                    .lineLimit(3...8)
                    .padding(.vertical, Spacing.sm)
                    .formFieldChrome()
            }
            LabeledFormField(label: "Website", text: $form.website, contentType: .URL, keyboard: .URL, capitalization: .never)

            sectionTitle("Contact")
            LabeledFormField(label: "Email", text: $form.email, systemImage: "envelope.fill", contentType: .emailAddress,
                             keyboard: .emailAddress, capitalization: .never, errorMessage: emailError,
                             identifier: "contactCard.email")
                .onChange(of: form.email) { emailError = nil }
            LabeledFormField(label: "Phone Number", text: $form.phone, systemImage: "phone.fill", contentType: .telephoneNumber, keyboard: .phonePad, capitalization: .never)
            LabeledFormField(label: "Alternate email", text: $form.alternateEmail, keyboard: .emailAddress, capitalization: .never)

            sectionTitle("Links")
            LabeledFormField(label: "LinkedIn", text: $form.linkedin, keyboard: .URL, capitalization: .never)
            LabeledFormField(label: "Twitter / X", text: $form.twitter, capitalization: .never)
            LabeledFormField(label: "Custom link", text: $form.customLink, keyboard: .URL, capitalization: .never)
            LabeledFormField(label: "Calendly", text: $form.calendly, keyboard: .URL, capitalization: .never)

            Button("Save", action: save)
                .buttonStyle(.primary)
                .disabled(isSaving)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.xl)
                .accessibilityIdentifier("contactCard.save")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var photo: some View {
        if let newPhoto {
            Image(uiImage: newPhoto)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .accessibilityLabel("Profile photo")
        } else if let url = app.dependencies.contactImages.url(for: existing?.profileImageFileName),
                  let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .accessibilityLabel("Profile photo")
        }
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.headline)
            .padding(.top, Spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }

    private func load() async {
        let user = await app.local.ensureUser()
        form.firstName = user.firstName ?? ""
        form.lastName = user.lastName ?? ""
        form.email = user.email ?? ""
        if let card = await app.local.contactCard() {
            existing = card
            form.jobTitle = card.jobTitle ?? ""
            form.company = card.company ?? ""
            form.description = card.description ?? ""
            form.website = card.website ?? ""
            form.phone = card.phone ?? ""
            form.alternateEmail = card.alternateEmail ?? ""
            form.linkedin = card.linkedin ?? ""
            form.twitter = card.twitter ?? ""
            form.customLink = card.customLink ?? ""
            form.calendly = card.calendly ?? ""
            if form.email.isEmpty { form.email = card.email ?? "" }
        }
        isLoading = false
    }

    private func takePhoto() {
        guard CameraCapture.isAvailable else {
            toast = ToastMessage(text: "Camera is unavailable on this device")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isCameraPresented = true
        case .notDetermined:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    isCameraPresented = true
                } else {
                    toast = ToastMessage(text: "Camera permission is needed to take a profile photo")
                }
            }
        default:
            toast = ToastMessage(text: "Camera permission is needed to take a profile photo")
        }
    }

    private func save() {
        let first = form.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = form.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = form.email.trimmingCharacters(in: .whitespacesAndNewlines)
        firstNameError = first.isEmpty ? "First name is required" : nil
        if email.isEmpty {
            emailError = "Email is required"
        } else if !CredentialRules.isValidEmail(email) {
            emailError = "Enter a valid email address"
        } else {
            emailError = nil
        }
        guard firstNameError == nil, emailError == nil else {
            toast = ToastMessage(text: "Please fix the highlighted fields")
            return
        }

        isSaving = true
        let dependencies = app.dependencies
        let form = form
        let existing = existing
        let photoData = newPhoto?.profileJPEGData()
        Task {
            let local = dependencies.local
            let user = await local.ensureUser()
            let changed = await local.updateProfile(firstName: first, lastName: last, email: email)
            changed.forEach { dependencies.analytics.log(.updateProfile(field: $0)) }

            var fileName = existing?.profileImageFileName
            if let photoData, let saved = try? dependencies.contactImages.save(jpegData: photoData) {
                dependencies.contactImages.delete(fileName)
                fileName = saved
            }
            let blank = ContactCardQRCodec.blankToNil
            let card = ContactCard(
                cardID: existing?.cardID ?? UUID().uuidString,
                ownerUserID: user.id,
                profileImageFileName: fileName,
                name: [first, last].filter { !$0.isEmpty }.joined(separator: " "),
                jobTitle: blank(form.jobTitle),
                company: blank(form.company),
                description: blank(form.description),
                email: email,
                phone: blank(form.phone),
                alternateEmail: blank(form.alternateEmail),
                website: blank(form.website),
                linkedin: blank(form.linkedin),
                twitter: blank(form.twitter),
                customLink: blank(form.customLink),
                calendly: blank(form.calendly),
                updatedAt: Date()
            )
            await local.saveContactCard(card)
            if existing == nil {
                dependencies.analytics.log(.createContactCard)
                await local.addTimelineEntry(.contactCardCreated, description: "Created a Tatum Tech contact card")
            }
            await app.refreshLocalUser()
            isSaving = false
            toast = ToastMessage(text: "Contact card saved")
            try? await Task.sleep(for: .milliseconds(900))
            router.pop()
        }
    }
}
