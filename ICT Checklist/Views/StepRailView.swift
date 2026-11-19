//
//  StepRailView.swift
//  ICT Checklist
//

import SwiftUI

struct StepRailView: View {
    let currentGroup: StepGroup

    private var nodes: [StepGroup] { StepGroup.allCases }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let slot = proxy.size.width / CGFloat(max(nodes.count, 1))
                let fullWidth = max(0, proxy.size.width - slot)
                let progressWidth = min(fullWidth, slot * CGFloat(currentGroup.rawValue))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: fullWidth, height: 2)
                    Capsule()
                        .fill(Theme.blue.opacity(0.9))
                        .frame(width: progressWidth, height: 2)
                }
                .offset(x: slot / 2, y: 7)
            }

            HStack(alignment: .top, spacing: 0) {
                ForEach(nodes) { group in
                    node(group)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentGroup)
    }

    private func node(_ group: StepGroup) -> some View {
        let isCurrent = group == currentGroup
        let isDone = group.rawValue < currentGroup.rawValue

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Theme.blue.opacity(0.35))
                    .frame(width: 24, height: 24)
                    .blur(radius: 6)
                    .opacity(isCurrent ? 1 : 0)
                Circle()
                    .fill(dotColor(isDone: isDone, isCurrent: isCurrent))
                    .frame(width: isCurrent ? 14 : 9, height: isCurrent ? 14 : 9)
                Circle()
                    .strokeBorder(Color.white.opacity(isCurrent ? 0.95 : 0), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
            .frame(height: 16)

            Text(group.title)
                .font(.system(size: 8.5, weight: isCurrent ? .bold : .semibold))
                .foregroundStyle(labelColor(isDone: isDone, isCurrent: isCurrent))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.blue)
                .opacity(isDone ? 1 : 0)
                .frame(height: 10)
        }
    }

    private func dotColor(isDone: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return .white }
        return isDone ? Theme.blue : Color.white.opacity(0.22)
    }

    private func labelColor(isDone: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return .white }
        return isDone ? Theme.blue : Theme.textSecondary
    }
}
