//
//  ViewExtension.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 05.10.23.
//

import SwiftUI

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


/// From iOS 26 on the system renders Live Activities on its Liquid Glass platter, which adapts to the wallpaper.
/// Older versions keep the fixed dark look.
var activityUsesSystemGlass: Bool {
    if #available(iOS 26.0, *) {
        return true
    }
    return false
}


extension UIColor {
    var dark: UIColor  { resolvedColor(with: .init(userInterfaceStyle: .dark))  }
    var light: UIColor { resolvedColor(with: .init(userInterfaceStyle: .light)) }
}
