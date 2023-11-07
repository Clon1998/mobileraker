//
//  CircularProgressView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 08.09.23.
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double
    var widthHeight: Double = 30
    var lineWidth: Double = 5
    var color_int: UInt32 = 0xFFFF0000
    private var isPrintDone: Bool {
        get {
            abs(progress - 1) < 0.0001
        }
    }
    
    var body: some View {
        if isPrintDone {
            Image(systemName: "checkmark.circle")
                .resizable()
                .frame(width: widthHeight, height: widthHeight)
                .foregroundColor(colorWithRGBA(color_int))
        } else {
            ZStack {
                Circle()
                    .stroke(
                        colorWithRGBA(color_int).opacity(0.3),
                        lineWidth: lineWidth
                    )
                    .frame(width: widthHeight, height: widthHeight)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        colorWithRGBA(color_int),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: widthHeight, height: widthHeight)
            }
        }
    }
    
    func colorWithRGBA(_ rgba: UInt32) -> Color {
        let red = CGFloat((rgba >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgba >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgba & 0xFF) / 255.0
        let alpha = CGFloat((rgba >> 24) & 0xFF) / 255.0
        
        return Color(UIColor(red: red, green: green, blue: blue, alpha: alpha))
    }
    
}

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack{
            CircularProgressView(progress: 0.5)
        }
        
    }
}
