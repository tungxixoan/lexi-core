"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuthUser } from "@/lib/useAuthUser";
import { SignInButton } from "@/components/SignInButton";
import { getVocabRecords, type VocabRecord } from "@/lib/vocabRecords";
import { computeLearningStats, type LearningStats } from "@/lib/learningStats";
import { getDailyActivity, type DailyActivity } from "@/lib/dailyActivity";

const CEFR_LEVELS: VocabRecord["cefrLevel"][] = ["a1", "a2", "b1", "b2", "c1", "c2"];
const CHART_DAYS = 7;

function dateKey(d: Date): string {
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function lastNDays(n: number, from: Date = new Date()): string[] {
  const keys: string[] = [];
  for (let i = n - 1; i >= 0; i--) {
    keys.push(dateKey(new Date(from.getTime() - i * 24 * 60 * 60 * 1000)));
  }
  return keys;
}

const WEEKDAY_LABELS_MON_FIRST = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"];

function weekdayLabel(key: string): string {
  const d = new Date(`${key}T00:00:00`);
  const jsDay = d.getDay(); // 0 = Sunday
  const monFirstIndex = jsDay === 0 ? 6 : jsDay - 1;
  return WEEKDAY_LABELS_MON_FIRST[monFirstIndex];
}

export default function DashboardPage() {
  const { user, loading: authLoading } = useAuthUser();
  const [records, setRecords] = useState<VocabRecord[] | null>(null);
  const [recordsError, setRecordsError] = useState(false);
  const [activity, setActivity] = useState<DailyActivity | null>(null);
  const [activityError, setActivityError] = useState(false);

  useEffect(() => {
    if (!user) return;
    getVocabRecords(user.uid)
      .then(setRecords)
      .catch(() => setRecordsError(true));
    getDailyActivity(user.uid)
      .then(setActivity)
      .catch(() => setActivityError(true));
  }, [user]);

  if (authLoading) return <p>Đang tải…</p>;

  if (!user) {
    return (
      <div>
        <h2 className="scr-title">Tổng quan</h2>
        <p className="scr-sub">Đăng nhập để xem tiến độ học tập.</p>
        <SignInButton />
      </div>
    );
  }

  if (records === null && !recordsError) return <p>Đang tải…</p>;

  const stats: LearningStats | null = records ? computeLearningStats(records) : null;
  const totalForChart = stats?.totalCount ?? 0;
  const chartDays = lastNDays(CHART_DAYS);
  const chartMax = activity ? Math.max(...chartDays.map((k) => activity.weeklyLog[k] ?? 0), 1) : 1;

  return (
    <div>
      <h2 className="scr-title">Tổng quan</h2>
      <p className="scr-sub">Tiến độ học tập của bạn, cập nhật theo thời gian thực.</p>

      {activityError && <p role="alert">Không tải được dữ liệu streak.</p>}

      {activity && (
        <div className="dash-streak-banner">
          {activity.currentStreak > 0 ? (
            <>
              <span className="dash-streak-emoji">🔥</span>
              <div>
                <div className="dash-streak-count">{activity.currentStreak}</div>
                <div className="dash-streak-sub">ngày liên tiếp</div>
              </div>
            </>
          ) : (
            <>
              <span className="dash-streak-emoji">❄️</span>
              <div>
                <div className="dash-streak-sub">Chưa có streak — luyện gì đó để bắt đầu!</div>
              </div>
            </>
          )}
        </div>
      )}

      {recordsError && <p role="alert">Không tải được dữ liệu từ vựng.</p>}

      {stats && (
        <>
          <div className="dash-stat-grid">
            <div className="dash-stat-card">
              <div className="dash-stat-label">Hôm nay</div>
              <div className="dash-stat-value">{stats.dueCount}</div>
              <div className="dash-stat-foot">từ đến hạn ôn tập</div>
            </div>
            <div className="dash-stat-card">
              <div className="dash-stat-label">Đã thuộc</div>
              <div className="dash-stat-value">{stats.masteredCount}</div>
              <div className="dash-stat-foot">/ {stats.totalCount} từ</div>
            </div>
          </div>

          {stats.dueCount > 0 && (
            <Link href="/practice?action=start" className="btn-primary dash-cta">
              Ôn {stats.dueCount} từ ngay <span aria-hidden="true">→</span>
            </Link>
          )}

          <div className="dash-card">
            <h3>Theo cấp độ CEFR</h3>
            <div className="dash-cefr-rows">
              {CEFR_LEVELS.map((level) => {
                const count = stats.cefrBreakdown[level];
                const pct = totalForChart === 0 ? 0 : (count / totalForChart) * 100;
                return (
                  <div key={level} className="dash-cefr-row">
                    <span className="dash-cefr-tag">{level.toUpperCase()}</span>
                    <div className="dash-cefr-track">
                      <div className="dash-cefr-fill" style={{ width: `${pct}%` }} />
                    </div>
                    <span className="dash-cefr-count">{count}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </>
      )}

      {activity && (
        <div className="dash-card">
          <h3>7 ngày gần đây</h3>
          <div className="dash-chart">
            {chartDays.map((key) => {
              const value = activity.weeklyLog[key] ?? 0;
              const pct = value === 0 ? 4 : Math.max(10, (value / chartMax) * 100);
              const isToday = key === dateKey(new Date());
              return (
                <div key={key} className={`dash-chart-col${isToday ? " today" : ""}`}>
                  <div className="dash-chart-bar-wrap">
                    <div className="dash-chart-bar" style={{ height: `${pct}%` }}>
                      <span className="dash-chart-value">{value}</span>
                    </div>
                  </div>
                  <div className="dash-chart-day">{weekdayLabel(key)}</div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
