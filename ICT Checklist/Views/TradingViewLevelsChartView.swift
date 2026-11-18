//
//  TradingViewLevelsChartView.swift
//  ICT Checklist
//
//  График TradingView (Lightweight Charts) с линиями сделки:
//  вход, стоп, тейк, ключевые уровни и текущая цена.
//

import SwiftUI
import WebKit

struct TradingViewLevel: Codable, Identifiable {
    let price: Double
    let title: String
    /// HEX без решётки.
    let color: String
    /// 0 — сплошная, 1 — точки, 2 — штрих.
    let style: Int

    var id: String { "\(title)|\(price)" }
}

struct TradingViewLevelsChartView: UIViewRepresentable {
    let symbol: String
    let interval: String
    let bars: [ChartBar]
    let levels: [TradingViewLevel]
    let currentPrice: Double?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false

        context.coordinator.lastKey = dataKey
        context.coordinator.lastPrice = currentPrice
        web.loadHTMLString(html, baseURL: URL(string: "https://www.tradingview.com"))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.lastKey != dataKey {
            context.coordinator.lastKey = dataKey
            context.coordinator.lastPrice = currentPrice
            web.loadHTMLString(html, baseURL: URL(string: "https://www.tradingview.com"))
            return
        }

        guard let price = currentPrice,
              context.coordinator.lastPrice != price else { return }
        context.coordinator.lastPrice = price
        let literal = String(format: "%.6f", price)
        web.evaluateJavaScript("window.setCurrentPrice(\(literal));")
    }

    final class Coordinator {
        var lastKey = ""
        var lastPrice: Double?
    }

    private var dataKey: String {
        "\(symbol)|\(interval)|\(bars.count)|\(bars.last?.time ?? 0)|\(levels.count)"
    }

    private var html: String {
        let barsJSON = (try? JSONEncoder().encode(bars)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let levelsJSON = (try? JSONEncoder().encode(levels)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let initialPrice = currentPrice.map { String(format: "%.6f", $0) } ?? "null"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { height: 100%; margin: 0; padding: 0; background: #000000; overflow: hidden; }
        #chart { height: 100%; width: 100%; }
        </style>
        </head>
        <body>
        <div id="chart"></div>
        <script src="https://unpkg.com/lightweight-charts@4.2.2/dist/lightweight-charts.standalone.production.js"></script>
        <script>
        const bars = \(barsJSON);
        const levels = \(levelsJSON);
        const initialPrice = \(initialPrice);

        const container = document.getElementById("chart");
        const chart = LightweightCharts.createChart(container, {
          autoSize: true,
          layout: {
            background: { type: "solid", color: "#000000" },
            textColor: "#E8E8E8",
            fontFamily: "-apple-system"
          },
          grid: {
            vertLines: { color: "rgba(255,255,255,0.05)" },
            horzLines: { color: "rgba(255,255,255,0.05)" }
          },
          rightPriceScale: { borderColor: "rgba(255,255,255,0.12)" },
          timeScale: { borderColor: "rgba(255,255,255,0.12)", timeVisible: true, secondsVisible: false },
          crosshair: { mode: 1 }
        });

        const series = chart.addCandlestickSeries({
          upColor: "#7BE3B0",
          downColor: "#FF8A8A",
          borderUpColor: "#7BE3B0",
          borderDownColor: "#FF8A8A",
          wickUpColor: "#7BE3B0",
          wickDownColor: "#FF8A8A"
        });

        series.setData(bars);
        chart.timeScale().fitContent();

        levels.forEach(function (line) {
          series.createPriceLine({
            price: line.price,
            color: "#" + line.color,
            lineWidth: 1,
            lineStyle: line.style,
            axisLabelVisible: true,
            title: line.title
          });
        });

        let currentLine = null;

        window.setCurrentPrice = function (price) {
          if (currentLine) {
            series.removePriceLine(currentLine);
            currentLine = null;
          }
          if (price === null || price === undefined) { return; }
          currentLine = series.createPriceLine({
            price: price,
            color: "#FFFFFF",
            lineWidth: 1,
            lineStyle: 1,
            axisLabelVisible: true,
            title: "Сейчас"
          });
        };

        window.setCurrentPrice(initialPrice);
        </script>
        </body>
        </html>
        """
    }
}
