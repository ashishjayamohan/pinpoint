import Foundation
import CoreLocation

struct Event: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var coordinate: CLLocationCoordinate2D
    var timestamp: Date
    
    // Radius in meters within which users should be notified
    var notificationRadius: Double
} 