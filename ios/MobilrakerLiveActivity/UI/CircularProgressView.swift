//
//  CircularProgressView.swift
//  MobilrakerLiveActivityExtension
//
//  Created by Patrick Schmidt on 08.09.23.
//

import SwiftUI

struct CircularProgressView: View {
    // 1
    let progress: Double
    
    var widthHeight: Double = 30
    
    var lineWidth: Double = 5
    
    var body: some View {
        ZStack {
            Circle(
        )
                .stroke(
                    Color.red.opacity(0.5),
                    lineWidth: lineWidth
                )
                .frame(width: widthHeight, height: widthHeight)
            Circle()
                // 2
                .trim(from: 0, to: progress)
                .stroke(
                    Color.red,
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
