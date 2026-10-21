import SwiftUI

// WidgetKit archives rectangular control frames. Decorative sector paths are
// not interaction boundaries. These non-overlapping rectangles tile the ring.
enum RingHitMap {
    struct Region: Identifiable {
        var id: Int
        var owner: Int
        var rect: CGRect
    }
    static func owner(at point: CGPoint, count: Int, side: CGFloat) -> Int? {
        let total = min(max(0, count), 34)
        let outerCount = total <= 20 ? total : Int(ceil(Double(total) * 20 / 34))
        let dx = point.x-side/2, dy = point.y-side/2
        let radius = hypot(dx,dy)
        let angle = (atan2(dy,dx) + .pi/2 + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        for ring in 0...1 {
            let size = ring == 0 ? outerCount : total - outerCount
            guard size > 0 else { continue }
            let outer = side/2-CGFloat(ring)*36
            if radius <= outer && radius >= outer-34 {
                let index = min(size-1, Int(angle/(2 * .pi)*Double(size)))
                return (ring == 0 ? 0 : outerCount) + index
            }
        }
        return nil
    }
    static func rectangles(count: Int, side: CGFloat) -> [Region] {
        let key = "\(count):\(side)"
        cacheLock.lock()
        if let value = cache[key] { cacheLock.unlock(); return value }
        cacheLock.unlock()
        let value = build(count: count, side: side)
        cacheLock.lock(); cache[key] = value; cacheLock.unlock()
        return value
    }
    private static let cacheLock = NSLock()
    private static var cache = [String:[Region]]()
    private static func build(count: Int, side: CGFloat) -> [Region] {
        guard count > 0 else { return [] }
        let cells = Int(ceil(side/8)), unit = side/CGFloat(cells)
        struct Key: Hashable { var owner: Int; var from: Int; var to: Int }
        var result = [Region](), active = [Key:Int]()
        for y in 0..<cells {
            var x = 0, next = [Key:Int]()
            while x < cells {
                let start = x
                let owner = owner(at: CGPoint(x: (CGFloat(x)+0.5)*unit, y: (CGFloat(y)+0.5)*unit), count: count, side: side)
                x += 1
                while x < cells && owner == self.owner(at: CGPoint(x: (CGFloat(x)+0.5)*unit, y: (CGFloat(y)+0.5)*unit), count: count, side: side) { x += 1 }
                guard let owner else { continue }
                let key = Key(owner: owner, from: start, to: x)
                if let index = active[key] {
                    result[index].rect.size.height += unit; next[key] = index
                } else {
                    let index = result.count
                    result.append(Region(id: index, owner: owner, rect: CGRect(x: CGFloat(start)*unit, y: CGFloat(y)*unit, width: CGFloat(x-start)*unit, height: unit)))
                    next[key] = index
                }
            }
            active = next
        }
        return result
    }
}
