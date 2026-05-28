#!/usr/bin/env bash
# i18n.sh — translation dictionary for CleanMyMac.
#
# Design (gettext-style):
#   • All user-facing strings in scripts are written in English at the call site.
#   • Wrap them with $(i18n "English literal"). The function returns the
#     localized form for $MAC_LANG, or the English source if no translation
#     exists (graceful fallback — adding new keys never breaks output).
#   • printf format specifiers (%s, %d) pass through unchanged; pass values
#     as separate printf args, e.g.
#         printf "$(i18n 'Reclaimed: %s\n')" "$human"
#
# Adding a new language:
#   1. Add a `_i18n_xx` function below (xx = ISO 639-1 code).
#   2. Add a case branch in `i18n()` that dispatches to it.
#   3. Add the detection pattern to lib.sh (the MAC_LANG block).
#
# Adding a new translatable string:
#   1. Wrap it with $(i18n "...") at the call site.
#   2. Add a `"English source") echo "翻译" ;;` line under each language
#      function below.
#   3. tests/test_i18n.sh will verify the key is present.

# i18n <english-key>
#   stdout: localized string (or the key itself if no translation).
i18n() {
  local k="$1"
  case "${MAC_LANG:-en}" in
    zh) _i18n_zh "$k" ;;
    *)  printf '%s' "$k" ;;
  esac
}

# Each per-language function: case on the English key, echo the translation.
# Fall through to echoing the key itself if no match — so adding new strings
# never produces empty output. Keep entries grouped by source script for review.
_i18n_zh() {
  case "$1" in

    # ── diskmap.sh ────────────────────────────────────────────────────────
    "Disk map")                                          printf '%s' "磁盘地图" ;;
    "Threshold ≥")                                       printf '%s' "阈值 ≥" ;;
    "auto-drilled to specific classifiable items")       printf '%s' "已自动深入到可分类的具体项目" ;;
    "some paths denied by macOS TCC — true totals may be higher") printf '%s' "部分路径被 macOS TCC 拒绝 — 实际总量可能更大" ;;
    "AUTO-SAFE — delete now")                            printf '%s' "安全清理 — 立即可删" ;;
    "NEEDS REVIEW — your call")                          printf '%s' "需要审核 — 你来决定" ;;
    "NEVER-TOUCH — protected (info only)")               printf '%s' "受保护 — 不动（仅供参考）" ;;
    "no impact, regenerable")                            printf '%s' "无影响，可重建" ;;
    "decide per item")                                   printf '%s' "逐项决定" ;;
    "user/system data")                                  printf '%s' "用户/系统数据" ;;
    "SIZE")                                              printf '%s' "大小" ;;
    "WHAT IT IS")                                        printf '%s' "是什么" ;;
    "WHERE")                                             printf '%s' "位置" ;;
    "items")                                             printf '%s' "项" ;;
    "Auto-safe (delete):")                               printf '%s' "安全清理（可直接删）：" ;;
    "Review (your call):")                               printf '%s' "需要审核（你决定）：" ;;
    "Never-touch (info):")                               printf '%s' "受保护（仅参考）：" ;;
    "Walking")                                           printf '%s' "正在扫描" ;;
    "this can take ~30s for a full home dir")            printf '%s' "全 home 目录约 30 秒" ;;

    # ── scan.sh ───────────────────────────────────────────────────────────
    "Scanning modules in %s...")                         printf '%s' "正在扫描模块：%s..." ;;
    "Scan complete: %d auto-safe (%s), %d review (%s), %d skipped.") \
                                                         printf '%s' "扫描完成：%d 项安全清理（%s），%d 项需审核（%s），%d 项跳过。" ;;

    # ── autoclean.sh — banners & sections ─────────────────────────────────
    "CleanMyMac — SCAN RESULTS")                       printf '%s' "CleanMyMac — 扫描结果" ;;
    "AUTO-SAFE")                                         printf '%s' "安全清理" ;;
    "NEEDS YOUR REVIEW")                                 printf '%s' "需你审核" ;;
    "SKIPPED")                                           printf '%s' "已跳过" ;;
    "caches & build artifacts, regenerable, no user impact") \
                                                         printf '%s' "缓存与构建产物，可重建，无影响" ;;
    "medium/high risk, decide per item")                 printf '%s' "中/高风险，逐项决定" ;;
    "need sudo or permission denied")                    printf '%s' "需 sudo 或权限被拒" ;;
    "modules")                                           printf '%s' "个模块" ;;
    "(none)")                                            printf '%s' "（无）" ;;

    # ── autoclean.sh — table & totals ─────────────────────────────────────
    "MODULE")                                            printf '%s' "模块" ;;
    "RISK")                                              printf '%s' "风险" ;;
    "WHAT IT IS / WHAT HAPPENS IF DELETED")              printf '%s' "是什么 / 删除会发生什么" ;;
    "Total reclaimable:")                                printf '%s' "可回收总计：" ;;
    "Disk free now:")                                    printf '%s' "当前可用空间：" ;;

    # ── autoclean.sh — next-steps prompt ──────────────────────────────────
    "Next steps (choose one):")                          printf '%s' "下一步（任选其一）：" ;;
    "AUTO-CLEAN safe items (recommended, no impact):")   printf '%s' "自动清理安全项（推荐，无影响）：" ;;
    "INTERACTIVE review of medium/high-risk items (one-by-one decision):") \
                                                         printf '%s' "逐项审核中/高风险项（一一决定）：" ;;
    "BOTH (auto-safe + interactive review):")            printf '%s' "两者都做（安全清理 + 逐项审核）：" ;;

    # ── autoclean.sh — execute flow ───────────────────────────────────────
    "STEP 1: SCAN (read-only)")                          printf '%s' "步骤 1：扫描（只读）" ;;
    "STEP 2: CLEAN (tier=%s)")                           printf '%s' "步骤 2：清理（层级=%s）" ;;
    "FINAL REPORT")                                      printf '%s' "最终报告" ;;
    "Reclaimed: %s")                                     printf '%s' "已回收：%s" ;;
    "Disk free: %s → %s")                                printf '%s' "可用空间：%s → %s" ;;
    "About to clean %s auto-safe + %s review.")          printf '%s' "即将清理 %s 安全项 + %s 审核项。" ;;
    "Pass --yes to skip this prompt.")                   printf '%s' "传 --yes 可跳过此确认。" ;;
    "Proceed? (yes/no): ")                               printf '%s' "继续？(yes/no)：" ;;
    "Cancelled.")                                        printf '%s' "已取消。" ;;
    "Running auto-safe modules (%s modules)...")         printf '%s' "运行安全清理模块（共 %s 个）..." ;;
    "No review-tier modules with data; skipping.")       printf '%s' "审核层级无可清理数据，跳过。" ;;
    "Interactive review (medium/high risk)")             printf '%s' "逐项审核（中/高风险）" ;;
    "For each module: [d]elete  [k]eep (skip)  [q]uit review") \
                                                         printf '%s' "每个模块：[d] 删除  [k] 保留（跳过）  [q] 退出审核" ;;
    "  [d]elete / [k]eep / [q]uit ? ")                   printf '%s' "  [d] 删除 / [k] 保留 / [q] 退出？" ;;
    "Deleting %s...")                                    printf '%s' "正在删除 %s..." ;;
    "Review aborted by user.")                           printf '%s' "用户中止审核。" ;;
    "Kept (skipped) %s.")                                printf '%s' "已保留（跳过）%s。" ;;
    "Reclaimed %s")                                      printf '%s' "已回收 %s" ;;

    # ── advisor.sh ────────────────────────────────────────────────────────
    "Smart Advisor — scanning for large/stale folders...") \
                                                         printf '%s' "智能建议器 — 正在扫描大/陈旧文件夹..." ;;
    "No advisor candidates found. Your large folders look reasonable.") \
                                                         printf '%s' "未发现建议项。你的大文件夹看起来都正常。" ;;
    "Found %d candidates for review:")                   printf '%s' "找到 %d 个待审核项：" ;;
    "ITEM")                                              printf '%s' "项目" ;;
    "LAST USED")                                         printf '%s' "最后访问" ;;
    "RECOMMENDATION")                                    printf '%s' "建议" ;;
    "PATH")                                              printf '%s' "路径" ;;
    "Re-run with --interactive to delete items one-by-one.") \
                                                         printf '%s' "加 --interactive 重跑可逐项删除。" ;;
    "Interactive review — for each item: [d]elete, [k]eep, [s]kip, [q]uit") \
                                                         printf '%s' "逐项审核 — 每项：[d] 删除、[k] 保留、[s] 跳过、[q] 退出" ;;
    "Path:")                                             printf '%s' "路径：" ;;
    "Size:")                                             printf '%s' "大小：" ;;
    "Last modified:")                                    printf '%s' "最后修改：" ;;
    "Recommendation:")                                   printf '%s' "建议：" ;;
    "  > [d/k/s/q]: ")                                   printf '%s' "  > [d/k/s/q]：" ;;
    "  ✓ Deleted: %s freed")                             printf '%s' "  ✓ 已删除：释放 %s" ;;
    "  ✗ Delete failed (see log)")                       printf '%s' "  ✗ 删除失败（详见日志）" ;;
    "  ⚠  Path outside whitelist. Refusing to delete from advisor.") \
                                                         printf '%s' "  ⚠  路径不在白名单内。建议器拒绝删除。" ;;
    "     To remove manually: rm -rf \"%s\"  (verify carefully first)") \
                                                         printf '%s' "     如需手动移除：rm -rf \"%s\"（请先仔细核对）" ;;
    "  Skipped.")                                        printf '%s' "  已跳过。" ;;
    "  Exiting.")                                        printf '%s' "  退出。" ;;
    "  Kept.")                                           printf '%s' "  已保留。" ;;
    "Advisor session complete. Total freed: %s")         printf '%s' "建议器会话结束。总计释放：%s" ;;

    # ── schedule.sh / unschedule.sh ───────────────────────────────────────
    "CleanMyMac — Scheduled Auto-Run Setup")           printf '%s' "CleanMyMac — 定时自动运行设置" ;;
    "How often should CleanMyMac run?")                printf '%s' "CleanMyMac 多久运行一次？" ;;
    "  1) Weekly (Sunday 3 AM)")                         printf '%s' "  1) 每周（周日 3:00）" ;;
    "  2) Every 2 weeks (1st and 15th of the month, 3 AM)") \
                                                         printf '%s' "  2) 每两周（每月 1 日和 15 日 3:00）" ;;
    "  3) Monthly (1st of the month, 3 AM)")             printf '%s' "  3) 每月（每月 1 日 3:00）" ;;
    "  4) Custom (you'll provide weekday + hour)")       printf '%s' "  4) 自定义（你指定星期 + 小时）" ;;
    "What should each run do?")                          printf '%s' "每次运行做什么？" ;;
    "  1) Clean safe categories (caches, logs, trash) + send notification  [recommended]") \
                                                         printf '%s' "  1) 清理安全类（缓存、日志、垃圾）+ 发送通知  [推荐]" ;;
    "  2) Clean all 51 modules + send notification")     printf '%s' "  2) 清理全部 51 个模块 + 发送通知" ;;
    "  3) Notify only (do not clean automatically — open Claude when ready)") \
                                                         printf '%s' "  3) 仅通知（不自动清理 — 你准备好时打开 Claude）" ;;
    "  Weekday (0=Sun, 1=Mon, ... 6=Sat): ")             printf '%s' "  星期（0=日，1=一，... 6=六）：" ;;
    "  Hour (0-23, e.g. 3 for 3 AM): ")                  printf '%s' "  小时（0-23，例如 3 表示 3:00）：" ;;
    "✓ Scheduled: %s (%s)")                              printf '%s' "✓ 已设定：%s（%s）" ;;
    "  Agent:  %s")                                      printf '%s' "  Agent：%s" ;;
    "  Log:    %s")                                      printf '%s' "  日志：  %s" ;;
    "  Status: %s")                                      printf '%s' "  状态：  %s" ;;
    "  Stop:   %s")                                      printf '%s' "  停止：  %s" ;;
    "✓ Scheduled. LaunchAgent: %s")                      printf '%s' "✓ 已设定。LaunchAgent：%s" ;;
    "  State: loaded")                                   printf '%s' "  状态：已加载" ;;
    "  State: NOT loaded (try: launchctl bootstrap gui/%s \"%s\")") \
                                                         printf '%s' "  状态：未加载（试试：launchctl bootstrap gui/%s \"%s\"）" ;;
    "  Log:   %s")                                       printf '%s' "  日志： %s" ;;
    "Not scheduled.")                                    printf '%s' "未设定定时任务。" ;;
    "(no calendar set)")                                 printf '%s' "（未设置日历）" ;;
    "No LaunchAgent installed (looked for %s).")         printf '%s' "未安装 LaunchAgent（已查找 %s）。" ;;
    "✓ Unscheduled. LaunchAgent removed: %s")            printf '%s' "✓ 已解除。LaunchAgent 已移除：%s" ;;

    # ── Fallback ──────────────────────────────────────────────────────────
    *)                                                   printf '%s' "$1" ;;
  esac
}
