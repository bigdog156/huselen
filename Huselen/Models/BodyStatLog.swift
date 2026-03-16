//
//  BodyStatLog.swift
//  Huselen
//
//  Historical body stats record — one entry per user per day.
//

import Foundation

struct BodyStatLog: Codable, Identifiable {
    var id: String
    var userId: String
    var loggedAt: Date
    var weight: Double?
    var bodyFat: Double?
    var muscleMass: Double?
    var neck: Double?
    var shoulder: Double?
    var arm: Double?
    var chest: Double?
    var waist: Double?
    var hip: Double?
    var thigh: Double?
    var calf: Double?
    var lowerHip: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case loggedAt = "logged_at"
        case weight
        case bodyFat = "body_fat"
        case muscleMass = "muscle_mass"
        case neck, shoulder, arm, chest, waist, hip, thigh, calf
        case lowerHip = "lower_hip"
    }

    // MARK: - Decoder

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        userId = try c.decode(String.self, forKey: .userId)
        let dateStr = try c.decode(String.self, forKey: .loggedAt)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        loggedAt = fmt.date(from: dateStr) ?? Date()
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        bodyFat = try c.decodeIfPresent(Double.self, forKey: .bodyFat)
        muscleMass = try c.decodeIfPresent(Double.self, forKey: .muscleMass)
        neck = try c.decodeIfPresent(Double.self, forKey: .neck)
        shoulder = try c.decodeIfPresent(Double.self, forKey: .shoulder)
        arm = try c.decodeIfPresent(Double.self, forKey: .arm)
        chest = try c.decodeIfPresent(Double.self, forKey: .chest)
        waist = try c.decodeIfPresent(Double.self, forKey: .waist)
        hip = try c.decodeIfPresent(Double.self, forKey: .hip)
        thigh = try c.decodeIfPresent(Double.self, forKey: .thigh)
        calf = try c.decodeIfPresent(Double.self, forKey: .calf)
        lowerHip = try c.decodeIfPresent(Double.self, forKey: .lowerHip)
    }

    // MARK: - Encoder (omit id so Postgres generates it on upsert)

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(userId, forKey: .userId)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        try c.encode(fmt.string(from: loggedAt), forKey: .loggedAt)
        try c.encodeIfPresent(weight, forKey: .weight)
        try c.encodeIfPresent(bodyFat, forKey: .bodyFat)
        try c.encodeIfPresent(muscleMass, forKey: .muscleMass)
        try c.encodeIfPresent(neck, forKey: .neck)
        try c.encodeIfPresent(shoulder, forKey: .shoulder)
        try c.encodeIfPresent(arm, forKey: .arm)
        try c.encodeIfPresent(chest, forKey: .chest)
        try c.encodeIfPresent(waist, forKey: .waist)
        try c.encodeIfPresent(hip, forKey: .hip)
        try c.encodeIfPresent(thigh, forKey: .thigh)
        try c.encodeIfPresent(calf, forKey: .calf)
        try c.encodeIfPresent(lowerHip, forKey: .lowerHip)
    }

    // MARK: - Init from Client

    init(userId: String, loggedAt: Date = Date(), client: Client) {
        self.id = UUID().uuidString
        self.userId = userId
        self.loggedAt = loggedAt
        self.weight = client.weight > 0 ? client.weight : nil
        self.bodyFat = client.bodyFat > 0 ? client.bodyFat : nil
        self.muscleMass = client.muscleMass > 0 ? client.muscleMass : nil
        self.neck = client.neck > 0 ? client.neck : nil
        self.shoulder = client.shoulder > 0 ? client.shoulder : nil
        self.arm = client.arm > 0 ? client.arm : nil
        self.chest = client.chest > 0 ? client.chest : nil
        self.waist = client.waist > 0 ? client.waist : nil
        self.hip = client.hip > 0 ? client.hip : nil
        self.thigh = client.thigh > 0 ? client.thigh : nil
        self.calf = client.calf > 0 ? client.calf : nil
        self.lowerHip = client.lowerHip > 0 ? client.lowerHip : nil
    }
}
