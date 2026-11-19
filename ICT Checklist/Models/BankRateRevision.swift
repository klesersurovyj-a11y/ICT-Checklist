//
//  BankRateRevision.swift
//  ICT Checklist
//
//  Ревизия ставки и ожиданий банка: журнал, который не перезаписывается.
//

import Foundation
import SwiftData

@Model
final class BankRateRevision {
    var createdAt: Date = Date()
    /// Валюта банка: USD, GBP, EUR.
    var currency: String = "USD"
    var bank: String = ""
    var rate: String = ""
    var expectations: String = ""
    var oneMonth: String = ""
    var quarter: String = ""
    var year: String = ""
    /// Метка силы валюты: сильная, слабая, нейтральная.
    var bias: String = ""
    var source: String = ""
    var note: String = ""

    init(
        createdAt: Date = .now,
        currency: String,
        bank: String,
        rate: String,
        expectations: String = "",
        oneMonth: String = "",
        quarter: String = "",
        year: String = "",
        bias: String = "",
        source: String = "",
        note: String = ""
    ) {
        self.createdAt = createdAt
        self.currency = currency
        self.bank = bank
        self.rate = rate
        self.expectations = expectations
        self.oneMonth = oneMonth
        self.quarter = quarter
        self.year = year
        self.bias = bias
        self.source = source
        self.note = note
    }
}
