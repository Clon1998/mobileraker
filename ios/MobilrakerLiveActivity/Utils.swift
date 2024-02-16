//
//  DateTimeUtils.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 16.09.23.
//

import SwiftUI


func colorWithRGBA(_ rgba: Int) -> Color{
    return colorWithRGBA(UInt32(rgba))
}

func colorWithRGBA(_ rgba: UInt32) -> Color {
    let red = CGFloat((rgba >> 16) & 0xFF) / 255.0
    let green = CGFloat((rgba >> 8) & 0xFF) / 255.0
    let blue = CGFloat(rgba & 0xFF) / 255.0
    let alpha = CGFloat((rgba >> 24) & 0xFF) / 255.0
    
    return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
}
