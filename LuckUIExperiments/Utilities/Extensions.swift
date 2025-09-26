// LuckUIExperiments::Extensions.swift - 18/08/2025

import Foundation

extension CGPoint {
    func add(x: CGFloat = 0, y: CGFloat = 0) -> CGPoint {
        return .init(x: self.x + x, y: self.y + y)
    }
}

extension CGSize {
    func add(width: CGFloat = 0, height: CGFloat = 0) -> CGSize {
        return .init(width: self.width + width, height: self.height + height)
    }
}
