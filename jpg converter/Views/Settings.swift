//
//  SettingsView.swift
//  Stock Profit Calculator
//
//  Created by Maicol Cabreja on 5/25/25.
//

import SwiftUI
import StoreKit
#if os(iOS)
import MessageUI
#endif
#if os(iOS)
struct MailView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var result: Result<MFMailComposeResult, Error>?

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var presentationMode: PresentationMode
        @Binding var result: Result<MFMailComposeResult, Error>?

        init(presentationMode: Binding<PresentationMode>, result: Binding<Result<MFMailComposeResult, Error>?>) {
            _presentationMode = presentationMode
            _result = result
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            defer {
                $presentationMode.wrappedValue.dismiss()
            }
            guard error == nil else {
                self.result = .failure(error!)
                return
            }
            self.result = .success(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode, result: $result)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<MailView>) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(["support@aivirx.com"])
        vc.setSubject("JPG Converter App")
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: UIViewControllerRepresentableContext<MailView>) {}
}
#endif

struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.requestReview) var requestReview
    @EnvironmentObject private var store: Store
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
#if os(iOS)
    @State private var result: Result<MFMailComposeResult, Error>? = nil
#endif
    @State private var isShowingMailView = false
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack{
                NavigationLink(destination: StoreView()) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Shop")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Unlock Premium Features")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.gradient))
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                Form {
                    Section(header: Text("Support Us")) {
                        Button {
                            requestReview()
                        } label: {
                            HStack {
                                Image(systemName: "star.leadinghalf.filled")
                                    .font(.system(size: 20))
                                    .frame(width: 30, height: 30)
                                    .foregroundStyle(.white)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                Text("Rate Us")
                            }
                        }
                    }
                    
                    Section(header: Text("Our Apps")) {
                        Link(destination: URL(string: "https://apps.apple.com/us/app/crypto-profit-loss-calculator/id1638849680")!) {
                            HStack {
                                Image("CryptoProfitCalc")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(5)
                                Text("Crypto Profit Loss Calculator")
                            }
                        }
                        
                        Link(destination: URL(string: "https://apps.apple.com/us/app/tasknow-simple-to-do-list/id1639588217")!) {
                            HStack {
                                Image("TaskNow")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .cornerRadius(5)
                                Text("TaskNow - Simple To Do List")
                            }
                        }
                    }
                    
                    Section("Privacy & Support") {
                        Link(destination: URL(string: "https://www.aivirx.com/stock-profit-calculator/privacy-policy")!) {
                            Text("Privacy Policy")
                        }
                        Button(action: {
                            isShowingMailView.toggle()
                        }) {
                            Text("Contact Us")
                        }
#if os(iOS)
                        .disabled(!MFMailComposeViewController.canSendMail())
#endif
                    }
                }
                .accentColor(colorScheme == .dark ? .white : .black)
#if os(iOS)
                .navigationBarTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
#endif
                .alert(isPresented: $showErrorAlert) {
                    Alert(
                        title: Text("Error"),
                        message: Text(errorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
#if os(iOS)
                .sheet(isPresented: $isShowingMailView) {
                    MailView(result: $result)
                }
#endif
            }
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
}
