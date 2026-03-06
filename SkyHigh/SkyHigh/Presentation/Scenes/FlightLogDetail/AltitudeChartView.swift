//
//  AltitudeChartView.swift
//  SkyHigh - ControllerApp
//
//  SwiftUI Charts 기반 고도 변화 그래프 (iOS 16+)

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct AltitudeChartView: View {

    let points: [TelemetryPoint]

    private var maxAlt: Double { points.map { $0.altitude }.max() ?? 10 }
    private var minAlt: Double { max((points.map { $0.altitude }.min() ?? 0) - 5, 0) }

    var body: some View {
        Chart(points) { point in
            // 그라데이션 영역
            AreaMark(
                x: .value("시간", point.timestamp),
                yStart: .value("하한", minAlt),
                yEnd:   .value("고도", point.altitude)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0, green: 0.83, blue: 1).opacity(0.35),
                        Color(red: 0, green: 0.83, blue: 1).opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint:   .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            // 라인
            LineMark(
                x: .value("시간", point.timestamp),
                y: .value("고도", point.altitude)
            )
            .foregroundStyle(Color(red: 0, green: 0.83, blue: 1))
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: minAlt ... (maxAlt + 5))
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel {
                    if let altitude = value.as(Double.self) {
                        Text("\(Int(altitude))m")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.gray)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.background(Color.clear)
        }
        .frame(height: 160)
    }
}
