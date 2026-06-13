//
//  Delaunay.swift
//  Mosaictor
//
//  Self-contained Bowyer–Watson Delaunay triangulation. Orientation-robust
//  circumcircle test so we can build new triangles from undirected edges.
//

import CoreGraphics

enum Delaunay {

    /// Returns triangles as index triples into `pts`.
    nonisolated static func triangulate(points pts: [CGPoint]) -> [(Int, Int, Int)] {
        let n = pts.count
        guard n >= 3 else { return [] }

        var points: [(x: Double, y: Double)] = pts.map { (Double($0.x), Double($0.y)) }
        // Encode an undirected edge (a,b) as a single Int key: min*stride + max.
        let stride = n + 3
        func edgeKey(_ x: Int, _ y: Int) -> Int { min(x, y) * stride + max(x, y) }

        // Super-triangle enclosing all points.
        var minX = Double.greatestFiniteMagnitude, minY = minX
        var maxX = -Double.greatestFiniteMagnitude, maxY = maxX
        for p in points {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        let dmax = max(maxX - minX, maxY - minY) * 20 + 10
        let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
        points.append((midX - dmax, midY - dmax))
        points.append((midX,        midY + dmax))
        points.append((midX + dmax, midY - dmax))
        let i0 = n, i1 = n + 1, i2 = n + 2

        var triangles: [(Int, Int, Int)] = [(i0, i1, i2)]

        for ip in 0..<n {
            let p = points[ip]
            var edgeCount: [Int: Int] = [:]
            var kept: [(Int, Int, Int)] = []
            kept.reserveCapacity(triangles.count)

            for t in triangles {
                if inCircumcircle(p, points[t.0], points[t.1], points[t.2]) {
                    edgeCount[edgeKey(t.0, t.1), default: 0] += 1
                    edgeCount[edgeKey(t.1, t.2), default: 0] += 1
                    edgeCount[edgeKey(t.2, t.0), default: 0] += 1
                } else {
                    kept.append(t)
                }
            }
            // Boundary edges (shared by exactly one bad triangle) form the hole.
            for (key, count) in edgeCount where count == 1 {
                kept.append((key / stride, key % stride, ip))
            }
            triangles = kept
        }

        // Discard triangles still attached to the super-triangle.
        return triangles.filter { $0.0 < n && $0.1 < n && $0.2 < n }
    }

    nonisolated private static func inCircumcircle(_ p: (x: Double, y: Double),
                                       _ a: (x: Double, y: Double),
                                       _ b: (x: Double, y: Double),
                                       _ c: (x: Double, y: Double)) -> Bool {
        let ax = a.x - p.x, ay = a.y - p.y
        let bx = b.x - p.x, by = b.y - p.y
        let cx = c.x - p.x, cy = c.y - p.y
        let det = (ax * ax + ay * ay) * (bx * cy - cx * by)
                - (bx * bx + by * by) * (ax * cy - cx * ay)
                + (cx * cx + cy * cy) * (ax * by - bx * ay)
        let orient = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        return orient > 0 ? det > 0 : det < 0
    }
}
