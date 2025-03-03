import Foundation
import CoreLocation
import UserNotifications
import FirebaseFirestore

class EventViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var events: [Event] = []
    @Published var userLatitude: Double?
    @Published var userLongitude: Double?
    private let locationManager = CLLocationManager()
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    var userLocation: CLLocationCoordinate2D? {
        if let lat = userLatitude, let lon = userLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    override init() {
        super.init()
        setupLocationManager()
        requestNotificationPermission()
        startListeningToEvents()
    }
    
    deinit {
        listenerRegistration?.remove()
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
            userLatitude = location.coordinate.latitude
            userLongitude = location.coordinate.longitude
        }
    }
    
    private func startListeningToEvents() {
        listenerRegistration = db.collection("events")
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error getting events: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No documents")
                    return
                }
                
                self.events = documents.compactMap { document -> Event? in
                    try? document.data(as: Event.self)
                }
                
                // Check for new events that need notifications
                self.checkForNewEvents(documents)
            }
    }
    
    private func checkForNewEvents(_ documents: [QueryDocumentSnapshot]) {
        guard let userLocation = userLocation else { return }
        
        let newEvents = documents.compactMap { document -> Event? in
            try? document.data(as: Event.self)
        }.filter { event in
            // Only consider events from the last minute as "new"
            let isRecent = event.timestamp.timeIntervalSinceNow > -60
            
            // Check if the event is within notification radius
            let eventLocation = CLLocation(latitude: event.latitude, longitude: event.longitude)
            let userCurrentLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
            let distance = eventLocation.distance(from: userCurrentLocation)
            
            return isRecent && distance <= event.notificationRadius
        }
        
        // Send notifications for new nearby events
        for event in newEvents {
            sendNotification(for: event)
        }
    }
    
    private func sendNotification(for event: Event) {
        let content = UNMutableNotificationContent()
        content.title = "New Event Nearby!"
        content.body = "\(event.title) - \(event.description)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: event.id ?? UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func addEvent(title: String, description: String, coordinate: CLLocationCoordinate2D) {
        let newEvent = Event(
            title: title,
            description: description,
            coordinate: coordinate
        )
        
        do {
            try db.collection("events").addDocument(from: newEvent)
        } catch {
            print("Error adding event: \(error.localizedDescription)")
        }
    }
} 
