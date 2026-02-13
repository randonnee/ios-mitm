import Foundation

struct LeafCertificateRecord: Codable {
    let host: String
    let certificatePEM: String
    let privateKeyPEM: String
    let expiresAt: Date
}

final class LeafCertificateCache {
    private let directory: URL
    private let queue: DispatchQueue
    private var records: [String: LeafCertificateRecord]

    init(directory: URL) {
        self.directory = directory
        self.queue = DispatchQueue(label: "ca.leaf.cache", attributes: .concurrent)
        self.records = [:]
        self.records = loadRecords()
    }

    func cachedCertificate(for host: String) -> LeafCertificateRecord? {
        queue.sync {
            guard let record = records[host], record.expiresAt > Date() else {
                return nil
            }
            return record
        }
    }

    func store(_ record: LeafCertificateRecord) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(record)
        let url = directory.appendingPathComponent(fileName(for: record.host))
        try data.write(to: url, options: .atomic)
        queue.async(flags: .barrier) {
            self.records[record.host] = record
        }
    }

    private func loadRecords() -> [String: LeafCertificateRecord] {
        var loaded: [String: LeafCertificateRecord] = [:]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return loaded
        }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let record = try? decoder.decode(LeafCertificateRecord.self, from: data) else {
                continue
            }
            loaded[record.host] = record
        }

        return loaded
    }

    private func fileName(for host: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        let sanitized = host.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(sanitized) + ".json"
    }
}
