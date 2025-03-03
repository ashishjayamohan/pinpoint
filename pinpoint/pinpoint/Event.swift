import Foundation
import CoreLocation
import FirebaseFirestore

struct Event: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var notificationRadius: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case latitude
        case longitude
        case timestamp
        case notificationRadius
    }
    
    init(id: String? = nil,
         title: String,
         description: String,
         coordinate: CLLocationCoordinate2D,
         timestamp: Date = Date(),
         notificationRadius: Double = 1000) {
        self.id = id
        self.title = title
        self.description = description
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timestamp = timestamp
        self.notificationRadius = notificationRadius
    }
} 
