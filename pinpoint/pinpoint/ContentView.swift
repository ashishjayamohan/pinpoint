//
//  ContentView.swift
//  pinpoint
//
//  Created by Ashish Jayamohan on 2/15/25.
//

import SwiftUI
import MapKit


struct ContentView: View {
    @StateObject private var viewModel = EventViewModel()
    @State private var showingEventSheet = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region,
                showsUserLocation: true,
                userTrackingMode: .constant(.follow),
                annotationItems: viewModel.events) { event in
                MapAnnotation(coordinate: event.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text(event.title)
                            .font(.caption)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location {
                                let coordinate = convertToCoordinate(location)
                                selectedLocation = coordinate
                                showingEventSheet = true
                            }
                        default:
                            break
                        }
                    }
            )
            .blur(radius: showingEventSheet ? 10 : 0)
            
            VStack {
                Spacer()
                Text("Long press to add an event")
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
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding()
            }
        }
        .animation(.spring(response: 0.3), value: showingEventSheet)
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
