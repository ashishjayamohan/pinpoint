import SwiftUI

struct EventFormView: View {
    @Binding var isPresented: Bool
    @Binding var eventTitle: String
    @Binding var eventDescription: String
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Log an Event")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding(.bottom)
            
            // Form Fields
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .foregroundStyle(.gray)
                    TextField("Event title", text: $eventTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .foregroundStyle(.gray)
                    TextEditor(text: $eventDescription)
                        .frame(height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            
            // Save Button
            Button(action: onSave) {
                Text("Log Event")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(eventTitle.isEmpty ? Color.blue.opacity(0.75) : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(eventTitle.isEmpty)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 10)
    }
} 
