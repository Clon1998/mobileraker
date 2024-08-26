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
    
    
    var body: some View {
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

struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack{
            CircularProgressView(progress: 0.5)
        }
        
    }
}
