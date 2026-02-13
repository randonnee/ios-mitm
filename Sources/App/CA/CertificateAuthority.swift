import Foundation
import Logging
import Crypto
@preconcurrency import X509
import SwiftASN1

enum CertificateAuthorityError: Error {
    case certificateCreationFailed
    case privateKeyExportFailed
    case saveFailed
    case loadFailed
    case missingSubject
}

final class CertificateAuthority {
    private let store: CertificateStore
    private let logger: Logger
    private let cache: LeafCertificateCache
    private var rootCertificate: Certificate?

    init(store: CertificateStore, logger: Logger) {
        self.store = store
        self.logger = logger
        self.cache = LeafCertificateCache(directory: store.leafDirectory)
    }

    func ensureRoot() throws -> Certificate.PrivateKey {
        if let root = try store.loadRootKey(),
           let certificate = try store.loadRootCertificate() {
            self.rootCertificate = certificate
            return root
        }

        logger.info("Generating new root CA certificate")
        let privateKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
        let certificate = try self.generateRootCertificate(key: privateKey)
        try store.save(rootKey: privateKey, certificate: certificate)
        self.rootCertificate = certificate
        return privateKey
    }

    func issueCertificate(for host: String) throws -> (certificate: Certificate, key: Certificate.PrivateKey) {
        if let cached = cache.cachedCertificate(for: host) {
            let certificate = try Certificate(pemEncoded: cached.certificatePEM)
            let key = try Certificate.PrivateKey(pemEncoded: cached.privateKeyPEM)
            return (certificate, key)
        }

        let issuerKey = try ensureRoot()
        guard let issuer = rootCertificate?.subject else {
            throw CertificateAuthorityError.missingSubject
        }

        let leafKey = Certificate.PrivateKey(P256.Signing.PrivateKey())
        let subject = try DistinguishedName {
            CommonName(host)
        }

        let serialBytes = Array(UUID().uuidString.utf8)
        let extensions = try Certificate.Extensions {
            SubjectAlternativeNames([.dnsName(host)])
            try ExtendedKeyUsage([.serverAuth])
        }

        let certificate = try Certificate(
            version: .v3,
            serialNumber: .init(bytes: serialBytes),
            publicKey: leafKey.publicKey,
            notValidBefore: Date(),
            notValidAfter: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date().addingTimeInterval(60 * 60 * 24 * 7),
            issuer: issuer,
            subject: subject,
            extensions: extensions,
            issuerPrivateKey: issuerKey
        )

        let certificatePEM = try certificate.serializeAsPEM().pemString
        let keyPEM = try leafKey.serializeAsPEM().pemString
        let record = LeafCertificateRecord(host: host, certificatePEM: certificatePEM, privateKeyPEM: keyPEM, expiresAt: certificate.notValidAfter)
        try cache.store(record)
        return (certificate, leafKey)
    }

    private func generateRootCertificate(key: Certificate.PrivateKey) throws -> Certificate {
        let subject = try DistinguishedName {
            CommonName("ios-mitm CA")
        }

        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: nil)
            )
            SubjectKeyIdentifier(hash: key.publicKey)
        }

        return try Certificate(
            version: .v3,
            serialNumber: .init(1),
            publicKey: key.publicKey,
            notValidBefore: Date(),
            notValidAfter: Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date().addingTimeInterval(60 * 60 * 24 * 365),
            issuer: subject,
            subject: subject,
            extensions: extensions,
            issuerPrivateKey: key
        )
    }
}

final class CertificateStore {
    private let directory: URL
    private let keyURL: URL
    private let certificateURL: URL
    let leafDirectory: URL

    init(path: String) {
        self.directory = URL(fileURLWithPath: path, isDirectory: true)
        self.keyURL = directory.appendingPathComponent("root-key.pem")
        self.certificateURL = directory.appendingPathComponent("root-cert.pem")
        self.leafDirectory = directory.appendingPathComponent("leaf")
    }

    func loadRootKey() throws -> Certificate.PrivateKey? {
        guard FileManager.default.fileExists(atPath: keyURL.path) else {
            return nil
        }

        let pemString = try String(contentsOf: keyURL)
        let pem = try PEMDocument(pemString: pemString)
        return try Certificate.PrivateKey(pemDocument: pem)
    }

    func save(rootKey: Certificate.PrivateKey, certificate: Certificate) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let keyPem = try rootKey.serializeAsPEM()
        try keyPem.pemString.write(to: keyURL, atomically: true, encoding: .utf8)
        let certPem = try certificate.serializeAsPEM()
        try certPem.pemString.write(to: certificateURL, atomically: true, encoding: .utf8)
    }

    func loadRootCertificate() throws -> Certificate? {
        guard FileManager.default.fileExists(atPath: certificateURL.path) else {
            return nil
        }

        let pemString = try String(contentsOf: certificateURL)
        return try Certificate(pemEncoded: pemString)
    }
}
