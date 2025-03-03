import Foundation
import CoreLocation
import UserNotifications
import FirebaseFirestore

class EventViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var events: [Event] = []
    @Published var userLatitude: Double?
    @Published var userLongitude: Double?
    @Published var isInitialLocationSet = false
    @Published var locationError: String?
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    
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
        print("EventViewModel: Initializing...")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // Initialize other services
        requestNotificationPermission()
        startListeningToEvents()
        
        // Trigger the authorization check through the delegate
        print("EventViewModel: Initial authorization status: \(locationManager.authorizationStatus.rawValue)")
        self.locationStatus = locationManager.authorizationStatus
        
        // This will trigger locationManagerDidChangeAuthorization
        if locationManager.authorizationStatus == .notDetermined {
            print("EventViewModel: Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Manually trigger the delegate method for existing authorization
            DispatchQueue.main.async {
                self.locationManagerDidChangeAuthorization(self.locationManager)
            }
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
    
    private func checkLocationAuthorization() {
        print("EventViewModel: Checking location authorization...")
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("EventViewModel: Authorization not determined, requesting...")
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            print("EventViewModel: Location access restricted")
            locationError = "Location access is restricted"
        case .denied:
            print("EventViewModel: Location access denied")
            locationError = "Location access is denied"
        case .authorizedAlways, .authorizedWhenInUse:
            print("EventViewModel: Location access authorized, starting updates...")
            locationManager.startUpdatingLocation()
        @unknown default:
            break
        }
        locationStatus = locationManager.authorizationStatus
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
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("EventViewModel: Authorization status changed to: \(manager.authorizationStatus.rawValue)")
        
        DispatchQueue.main.async {
            self.locationStatus = manager.authorizationStatus
            
            if !CLLocationManager.locationServicesEnabled() {
                self.locationError = "Location services are disabled"
                return
            }
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                print("EventViewModel: Location access granted, starting updates...")
                self.locationError = nil
                manager.startUpdatingLocation()
                
            case .notDetermined:
                print("EventViewModel: Location access not determined")
                self.locationError = nil
                
            case .denied:
                print("EventViewModel: Location access denied")
                self.locationError = "Please enable location access in Settings to see nearby events"
                
            case .restricted:
                print("EventViewModel: Location access restricted")
                self.locationError = "Location access is restricted on this device"
                
            @unknown default:
                break
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("EventViewModel: Received location update. Accuracy: \(location.horizontalAccuracy)")
        
        DispatchQueue.main.async {
            // Accept any location update initially
            if self.userLatitude == nil || self.userLongitude == nil {
                print("EventViewModel: Setting initial location: \(location.coordinate)")
                self.userLatitude = location.coordinate.latitude
                self.userLongitude = location.coordinate.longitude
                self.isInitialLocationSet = true
                return
            }
            
            // For subsequent updates, only update if reasonably accurate
            if location.horizontalAccuracy <= 100 {
                print("EventViewModel: Updating location: \(location.coordinate)")
                self.userLatitude = location.coordinate.latitude
                self.userLongitude = location.coordinate.longitude
                
                // Once we have a good location, we can reduce update frequency
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.distanceFilter = 10 // Only update if moved 10 meters
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("EventViewModel: Location manager failed with error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Location access denied. Please enable in Settings."
                case .locationUnknown:
                    self.locationError = "Unable to determine location"
                default:
                    self.locationError = "Error getting location: \(clError.localizedDescription)"
                }
            } else {
                self.locationError = "Unknown error getting location"
            }
        }
    }
} 
