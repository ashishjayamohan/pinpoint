//
//  ContentView.swift
//  pinpoint
//
//  Created by Ashish Jayamohan on 2/15/25.
//

import SwiftUI
import MapKit
import CoreHaptics


struct ContentView: View {
    @StateObject private var viewModel = EventViewModel()
    @State private var showingEventSheet = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var showingRateLimitAlert = false
    @State private var rateLimitMessage = "Rate Limited"
    @State private var region = MKCoordinateRegion(
        // Start with a zoomed out view
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 180)
    )
    @State private var temporaryPin: CLLocationCoordinate2D?
    @State private var longPressLocation: CGPoint?
    @State private var isLongPressing = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                userTrackingMode: .constant(.follow),
                annotationItems: viewModel.events + (temporaryPin.map { [Event(title: "New Event", description: "", coordinate: $0)] } ?? [])) { event in
                MapAnnotation(coordinate: event.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(event.id == nil ? .blue : .red)
                        if event.id != nil {
                            Text(event.title)
                                .font(.caption)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isLongPressing {
                            // Cancel if dragged while long pressing
                            isLongPressing = false
                            temporaryPin = nil
                            selectedLocation = nil
                            showingEventSheet = false
                        }
                        longPressLocation = value.location
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.7)
                    .onEnded { _ in
                        let (canCreate, message) = viewModel.canCreateNewEvent()
                        if !canCreate {
                            rateLimitMessage = message ?? "You've reached the event creation limit"
                            showingRateLimitAlert = true
                            return
                        }
                        
                        isLongPressing = true
                        if let location = longPressLocation {
                            let coordinate = convertToCoordinate(location)
                            temporaryPin = coordinate
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            
                            // Short delay before showing the form
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                selectedLocation = coordinate
                                showingEventSheet = true
                                isLongPressing = false
                            }
                        }
                    }
            )
            .blur(radius: showingEventSheet ? 10 : 0)
            
            // Location error overlay
            if let error = viewModel.locationError {
                VStack {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    
                    if viewModel.locationStatus == .denied {
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.top, -10)
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
            
            VStack {
                Spacer()
                Text("Hold for 1 second to add an event")
                    .padding()
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.bottom)
            }
            .allowsHitTesting(!showingEventSheet)
            
            if showingEventSheet {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        showingEventSheet = false
                        eventTitle = ""
                        eventDescription = ""
                        temporaryPin = nil
                    }
                
                EventFormView(
                    isPresented: $showingEventSheet,
                    eventTitle: $eventTitle,
                    eventDescription: $eventDescription,
                    onSave: {
                        if let location = selectedLocation {
                            viewModel.addEvent(
                                title: eventTitle,
                                description: eventDescription,
                                coordinate: location
                            )
                            eventTitle = ""
                            eventDescription = ""
                            showingEventSheet = false
                            temporaryPin = nil
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding()
            }
        }
        .animation(.spring(response: 0.3), value: showingEventSheet)
        .animation(.easeInOut, value: viewModel.locationError)
        .alert("Event Creation Limit", isPresented: $showingRateLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(rateLimitMessage)
        }
        .onChange(of: viewModel.userLatitude) { _ in
            updateRegionIfNeeded()
        }
        .onChange(of: viewModel.userLongitude) { _ in
            updateRegionIfNeeded()
        }
    }
    
    private func updateRegionIfNeeded() {
        if let lat = viewModel.userLatitude,
        let lon = viewModel.userLongitude,
        !viewModel.isInitialLocationSet {
            print("ContentView: Updating region to user location: \(lat), \(lon)")
            viewModel.isInitialLocationSet = true
            withAnimation {
                centerMapOnLocation(latitude: lat, longitude: lon)
            }
        }
    }
    
    private func centerMapOnLocation(latitude: Double, longitude: Double) {
        print("ContentView: Centering map on: \(latitude), \(longitude)")
        let newRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        region = newRegion
    }
    
    private func convertToCoordinate(_ point: CGPoint) -> CLLocationCoordinate2D {
        let rect = UIScreen.main.bounds
        let midX = rect.width / 2
        let midY = rect.height / 2
        
        let deltaLat = region.span.latitudeDelta * (point.y - midY) / rect.height
        let deltaLon = region.span.longitudeDelta * (point.x - midX) / rect.width
        
        return CLLocationCoordinate2D(
            latitude: region.center.latitude - deltaLat,
            longitude: region.center.longitude + deltaLon
        )
    }
}

#Preview {
    ContentView()
}
