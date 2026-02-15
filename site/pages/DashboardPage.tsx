
import React, { useState, useEffect } from 'react';
import StatsCard from '../components/StatsCard';
import RecentTransactions from '../components/RecentTransactions';
import {
  DollarSign,
  ArrowUpRight,
  ArrowDownLeft,
  CreditCard,
  Loader2
} from 'lucide-react';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer
} from 'recharts';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

const DashboardPage: React.FC = () => {
  const { t, currentLang } = useTranslation();
  const locale = currentLang === 'ar' ? 'ar-SA' : currentLang === 'en' ? 'en-US' : 'tr-TR';
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    totalBalance: 0,
    monthlyIncome: 0,
    monthlyExpense: 0,
    pendingPayments: 0
  });
  const [chartData, setChartData] = useState<any[]>([]);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    setLoading(true);
    try {
      // Fetch stats (Mock logic for now, or sum transactions)
      const { data: transactions, error } = await supabase
        .from('transactions')
        .select('*');

      if (error) throw error;

      if (transactions) {
        let income = 0;
        let expense = 0;
        transactions.forEach(tx => {
          const amount = Number(tx.amount);
          if (tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade') {
            income += amount;
          } else {
            expense += amount;
          }
        });

        setStats({
          totalBalance: income - expense,
          monthlyIncome: income,
          monthlyExpense: expense,
          pendingPayments: 0 // Fetch from a separate logic if status is 'pending'
        });

        // Group by day for chart (Locale-based weekdays)
        const weekdayFormatter = new Intl.DateTimeFormat(locale, { weekday: 'short' });
        const weekDayOrder = [1, 2, 3, 4, 5, 6, 0]; // Mon..Sun
        const daysMap: Record<number, { income: number; expense: number }> = {};
        weekDayOrder.forEach((dayIdx) => {
          daysMap[dayIdx] = { income: 0, expense: 0 };
        });

        transactions.forEach(tx => {
          const day = new Date(tx.transaction_date).getDay();
          const amount = Number(tx.amount);
          if (tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade') {
            daysMap[day].income += amount;
          } else {
            daysMap[day].expense += amount;
          }
        });

        const formattedChartData = weekDayOrder.map((dayIdx) => ({
          name: weekdayFormatter.format(new Date(2024, 0, 7 + dayIdx)),
          ...daysMap[dayIdx],
        }));

        setChartData(formattedChartData);
      }
    } catch (err) {
      console.error('Error fetching dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="h-[60vh] flex items-center justify-center">
        <Loader2 className="animate-spin text-secondary" size={40} />
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-in fade-in duration-500">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatsCard
          label={t('dashboard_total_balance')}
          value={`₺${stats.totalBalance.toLocaleString(locale)}`}
          trend={12.5}
          icon={<DollarSign size={20} />}
          color="bg-blue-500"
        />
        <StatsCard
          label={t('dashboard_monthly_income')}
          value={`₺${stats.monthlyIncome.toLocaleString(locale)}`}
          trend={8.2}
          icon={<ArrowUpRight size={20} />}
          color="bg-green-500"
        />
        <StatsCard
          label={t('dashboard_monthly_expense')}
          value={`₺${stats.monthlyExpense.toLocaleString(locale)}`}
          trend={-2.4}
          icon={<ArrowDownLeft size={20} />}
          color="bg-red-500"
        />
        <StatsCard
          label={t('dashboard_pending_payments')}
          value={`₺${stats.pendingPayments.toLocaleString(locale)}`}
          trend={1.2}
          icon={<CreditCard size={20} />}
          color="bg-amber-500"
        />
      </div>

      {/* Charts and Lists Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Income Chart */}
        <div className="lg:col-span-2 bg-paper-light dark:bg-paper-dark rounded-xl p-6 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-base font-semibold text-primary dark:text-white tracking-tight">{t('dashboard_weekly_analysis')}</h3>
            <select className="bg-gray-50 dark:bg-gray-800 border-none rounded text-[10px] font-black tracking-widest px-2 py-1 outline-none text-muted">
              <option>{t('dashboard_range_last_7_days')}</option>
              <option>{t('dashboard_range_last_30_days')}</option>
            </select>
          </div>
          <div className="h-[300px] w-full relative">
            <ResponsiveContainer width="100%" height="100%" minWidth={0}>
              <AreaChart data={chartData} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorGelir" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#EA4335" stopOpacity={0.1} />
                    <stop offset="95%" stopColor="#EA4335" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="colorGider" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#2C3E50" stopOpacity={0.1} />
                    <stop offset="95%" stopColor="#2C3E50" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#95A5A620" />
                <XAxis
                  dataKey="name"
                  axisLine={false}
                  tickLine={false}
                  tick={{ fontSize: 10, fill: '#95A5A6', fontWeight: 900 }}
                />
                <YAxis
                  axisLine={false}
                  tickLine={false}
                  tick={{ fontSize: 10, fill: '#95A5A6', fontWeight: 900 }}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: 'rgba(44, 62, 80, 0.95)',
                    border: 'none',
                    borderRadius: '8px',
                    color: '#fff',
                    fontSize: '11px',
                    fontWeight: 'bold'
                  }}
                  itemStyle={{ color: '#fff' }}
                />
                <Area
                  type="monotone"
                  dataKey="income"
                  name={t('dashboard_income')}
                  stroke="#EA4335"
                  strokeWidth={3}
                  fillOpacity={1}
                  fill="url(#colorGelir)"
                />
                <Area
                  type="monotone"
                  dataKey="expense"
                  name={t('dashboard_expense')}
                  stroke="#2C3E50"
                  strokeWidth={2}
                  fillOpacity={1}
                  fill="url(#colorGider)"
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Recent Transactions */}
        <div className="lg:col-span-1 bg-paper-light dark:bg-paper-dark rounded-xl p-4 md:p-6 shadow-sm border border-gray-100 dark:border-gray-800">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-base font-semibold text-primary dark:text-white tracking-tight">{t('dashboard_recent_transactions')}</h3>
            <span className="text-[10px] text-muted font-black tracking-widest">{t('dashboard_real_time')}</span>
          </div>
          <RecentTransactions />
        </div>
      </div>
    </div>
  );
};

export default DashboardPage;
