import Foundation

/// 预警判定引擎：纯逻辑、运行态不持久化。
///
/// 设计要点：
/// - 穿越即触发一次：仅在「未越过 → 越过」跳变时触发；停留在越过侧不重复触发。
/// - 首帧/重连同步：状态缺失时（`prev == nil`）只写入状态、不触发，避免误报。
/// - 同一 tick 多条规则全部触发（不做合并）。
/// - 状态字典为内存态，App 重启天然走首帧同步路径。
@MainActor
final class AlertEngine {
    /// 每条规则是否已处于「越过阈值」侧（true=越过，false=未越过）。缺失=尚未观测过。
    private var breached: [UUID: Bool] = [:]

    /// 对单个 ticker 评估所有规则，返回本次应触发的记录列表（可能为空或多条）。
    func evaluate(alerts: [PriceAlert], ticker: Ticker, period: PricePeriod) -> [AlertTriggerRecord] {
        guard !alerts.isEmpty else { return [] }
        var triggers: [AlertTriggerRecord] = []
        for alert in alerts {
            // 仅启用规则参与；禁用规则保持原状态不变，避免重新启用时基于过期状态误判
            guard alert.enabled else { continue }
            guard alert.instId == ticker.instId else { continue }

            let isOver = alert.isBreached(by: ticker, period: period)
            let prev = breached[alert.id]

            if prev == nil {
                // 首帧：仅同步状态，不触发
                breached[alert.id] = isOver
                continue
            }

            // 跳变 false -> true 才触发；true -> true 不重复；true/false 维持不发
            if prev == false && isOver {
                breached[alert.id] = true
                triggers.append(
                    AlertTriggerRecord(
                        instId: alert.instId,
                        symbol: ticker.symbol,
                        type: alert.type,
                        direction: alert.direction,
                        threshold: alert.threshold,
                        triggeredPrice: ticker.last,
                        triggeredChangePct: ticker.changePct(for: period),
                        note: alert.note
                    )
                )
            } else {
                // 状态可能从 true -> false（回到阈值另一侧），更新之以便下次穿越可再触发
                breached[alert.id] = isOver
            }
        }
        return triggers
    }

    /// 删除单条规则时清理其运行态
    func removeState(_ id: UUID) {
        breached.removeValue(forKey: id)
    }

    /// 删除某 instId 下所有规则时清理对应运行态
    func clearInstId(_ instId: String, alerts: [PriceAlert]) {
        for alert in alerts where alert.instId == instId {
            breached.removeValue(forKey: alert.id)
        }
    }

    /// 重连后调用：清空全部状态，使下一帧退化为首帧同步（不发通知）
    func reset() {
        breached.removeAll()
    }
}
