import SwiftUI

// Perceptual graph coloring: same-ring neighbors (including the seam) and
// overlapping inner/outer sectors cannot share a hue family or near color.
enum RingColors {
    static let palette: [(Double, Double, Double, Int)] = [
        // Fresh red, bright yellow, sky blue, crystal green, light purple.
        // Reuse only these five families; adjacency still takes priority.
        (1.00,0.58,0.62,3), (1.00,0.90,0.32,2), (0.45,0.78,0.98,0),
        (0.43,0.85,0.65,1), (0.76,0.67,0.96,4)
    ]
    static func color(_ index: Int) -> Color {
        let v = palette[index]; return Color(red: v.0, green: v.1, blue: v.2)
    }
    static func lab(_ v: (Double, Double, Double, Int)) -> [Double] {
        func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        let r = linear(v.0), g = linear(v.1), b = linear(v.2)
        let x = (0.4124564*r + 0.3575761*g + 0.1804375*b) / 0.95047
        let y = 0.2126729*r + 0.7151522*g + 0.0721750*b
        let z = (0.0193339*r + 0.1191920*g + 0.9503041*b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? pow(t, 1.0/3) : 7.787*t + 16.0/116 }
        return [116*f(y)-16, 500*(f(x)-f(y)), 200*(f(y)-f(z))]
    }
    static let labs = palette.map(lab)
    static func distance(_ a: Int, _ b: Int) -> Double { sqrt(zip(labs[a], labs[b]).map { pow($0-$1, 2) }.reduce(0,+)) }
    static func distinct(_ a: Int, _ b: Int) -> Bool { palette[a].3 != palette[b].3 && distance(a,b) >= 25 }
    static func adjacent(_ a: RingPosition, _ b: RingPosition) -> Bool {
        if a.ring == b.ring { return abs(a.index-b.index) == 1 || abs(a.index-b.index) == a.count-1 }
        let lo = max(Double(a.index)/Double(a.count), Double(b.index)/Double(b.count))
        let hi = min(Double(a.index+1)/Double(a.count), Double(b.index+1)/Double(b.count))
        return hi-lo > 0.000001
    }
    static func assign(_ total: Int) -> [Int] {
        cacheLock.lock()
        if let value = cache[total] { cacheLock.unlock(); return value }
        cacheLock.unlock()
        let value = compute(total)
        cacheLock.lock(); cache[total] = value; cacheLock.unlock()
        return value
    }
    private static let cacheLock = NSLock()
    private static var cache = [Int:[Int]]()
    private static func compute(_ total: Int) -> [Int] {
        let slots = RingPosition.slots(total), n = slots.count
        guard n > 0 else { return [] }
        let neighbors = slots.map { a in slots.filter { $0.id != a.id && adjacent(a,$0) }.map(\.id) }
        var assigned = Array(repeating: -1, count: n), uses = Array(repeating: 0, count: palette.count)
        func search(_ remaining: Int) -> Bool {
            if remaining == 0 { return true }
            let open = (0..<n).filter { assigned[$0] < 0 }
            let node = open.max { a,b in
                let sa = Set(neighbors[a].filter { assigned[$0] >= 0 }.map { palette[assigned[$0]].3 }).count
                let sb = Set(neighbors[b].filter { assigned[$0] >= 0 }.map { palette[assigned[$0]].3 }).count
                if sa != sb { return sa < sb }
                if neighbors[a].count != neighbors[b].count { return neighbors[a].count < neighbors[b].count }
                return a > b
            }!
            let candidates = palette.indices.sorted { uses[$0]*30 + $0 < uses[$1]*30 + $1 }
            for color in candidates where neighbors[node].allSatisfy({ assigned[$0] < 0 || distinct(color, assigned[$0]) }) {
                assigned[node] = color; uses[color] += 1
                if search(remaining-1) { return true }
                uses[color] -= 1; assigned[node] = -1
            }
            return false
        }
        precondition(search(n), "Palette must cover every verified 0...34-sector layout")
        return assigned
    }
}
