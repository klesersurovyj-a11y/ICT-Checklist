//
//  TradingViewChartView.swift
//  ICT Checklist
//
//  Встроенный график TradingView: инструменты, таймфреймы, разметка.
//

import SwiftUI
import WebKit

enum TVInterval: String, CaseIterable, Identifiable {
    case m15 = "15"
    case h1 = "60"
    case h4 = "240"
    case d1 = "D"
    case w1 = "W"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .m15: return "15м"
        case .h1: return "1ч"
        case .h4: return "4ч"
        case .d1: return "1д"
        case .w1: return "1н"
        }
    }
}

enum TradingViewSymbol {
    /// Приводит тикер приложения к символу TradingView.
    static func map(_ raw: String) -> String {
        let symbol = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !symbol.isEmpty else { return "FX:EURUSD" }
        if symbol.contains(":") { return symbol }

        switch symbol {
        case "XAUUSD":
            return "OANDA:XAUUSD"
        case "XAGUSD":
            return "OANDA:XAGUSD"
        case "US500", "SPX", "SPX500":
            return "SP:SPX"
        case "NAS100", "US100", "NDX":
            return "NASDAQ:NDX"
        case "GER40", "DE40", "DAX":
            return "XETR:DAX"
        case "DXY":
            return "TVC:DXY"
        case "USOIL", "WTI":
            return "TVC:USOIL"
        case "UKOIL", "BRENT":
            return "TVC:UKOIL"
        default:
            break
        }

        if symbol.hasPrefix("BTC") || symbol.hasPrefix("ETH") || symbol.hasPrefix("SOL") {
            return "COINBASE:\(symbol)"
        }
        if symbol.count == 6, symbol.allSatisfy({ $0.isLetter }) {
            return "FX:\(symbol)"
        }
        return symbol
    }

    /// Отображаемое имя без биржи.
    static func display(_ symbol: String) -> String {
        symbol.split(separator: ":").last.map(String.init) ?? symbol
    }
}

struct TradingViewChartView: UIViewRepresentable {
    let symbol: String
    let interval: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false

        let web = WKWebView(frame: .zero, configuration: configuration)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.navigationDelegate = context.coordinator

        context.coordinator.lastKey = key
        web.loadHTMLString(html, baseURL: URL(string: "https://www.tradingview.com"))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard context.coordinator.lastKey != key else { return }
        context.coordinator.lastKey = key
        web.loadHTMLString(html, baseURL: URL(string: "https://www.tradingview.com"))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastKey = ""
    }

    private var key: String {
        "\(symbol)|\(interval)"
    }

    private var html: String {
        let safeSymbol = symbol.filter { $0.isLetter || $0.isNumber || ":_-.".contains($0) }
        let safeInterval = interval.filter { $0.isLetter || $0.isNumber }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        html, body { height: 100%; margin: 0; padding: 0; background: #000000; overflow: hidden; }
        #tv_chart { height: 100%; width: 100%; }
        .tradingview-widget-container { height: 100%; width: 100%; }
        </style>
        </head>
        <body>
        <div class="tradingview-widget-container">
          <div id="tv_chart"></div>
        </div>
        <script src="https://s3.tradingview.com/tv.js"></script>
        <script>
        new TradingView.widget({
          "container_id": "tv_chart",
          "autosize": true,
          "symbol": "\(safeSymbol)",
          "interval": "\(safeInterval)",
          "timezone": "Etc/UTC",
          "theme": "dark",
          "style": "1",
          "locale": "ru",
          "toolbar_bg": "#000000",
          "enable_publishing": false,
          "allow_symbol_change": true,
          "save_image": false,
          "withdateranges": true,
          "details": true,
          "hotlist": false,
          "calendar": false,
          "studies": []
        });
        </script>
        </body>
        </html>
        """
    }
}
