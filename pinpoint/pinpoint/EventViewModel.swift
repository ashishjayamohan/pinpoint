import Foundation
import CoreLocation
import UserNotifications

class EventViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var events: [Event] = []
    @Published var userLocation: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        setupLocationManager()
        requestNotificationPermission()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location.coordinate
        }
    }
    
    func addEvent(title: String, description: String, coordinate: CLLocationCoordinate2D) {
        let newEvent = Event(title: title,
                           description: description,
                           coordinate: coordinate,
                           timestamp: Date(),
                           notificationRadius: 1000) // Default 1km radius
        events.append(newEvent)
        notifyNearbyUsers(for: newEvent)
    }
    
    private func notifyNearbyUsers(for event: Event) {
        guard let userLocation = userLocation else { return }
        
        let eventLocation = CLLocation(latitude: event.coordinate.latitude,
                                     longitude: event.coordinate.longitude)
        let userCurrentLocation = CLLocation(latitude: userLocation.latitude,
                                           longitude: userLocation.longitude)
        
        let distance = eventLocation.distance(from: userCurrentLocation)
        
        if distance <= event.notificationRadius {
            let content = UNMutableNotificationContent()
            content.title = "New Event Nearby!"
            content.body = "\(event.title) - \(event.description)"
            content.sound = .default
            
            let request = UNNotificationRequest(identifier: event.id.uuidString,
                                              content: content,
                                              trigger: nil)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
} 
