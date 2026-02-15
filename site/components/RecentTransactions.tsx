
import React, { useState, useEffect } from 'react';
import { Transaction } from '../types';
import { ArrowUpRight, ArrowDownLeft, Loader2 } from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

const RecentTransactions: React.FC = () => {
  const { t, currentLang } = useTranslation();
  const [transactions, setTransactions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const locale = currentLang === 'ar' ? 'ar-SA' : currentLang === 'en' ? 'en-US' : 'tr-TR';

  useEffect(() => {
    fetchRecentTransactions();
  }, []);

  const fetchRecentTransactions = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('transactions')
        .select('*')
        .order('transaction_date', { ascending: false })
        .limit(5);

      if (error) throw error;
      setTransactions(data || []);
    } catch (err) {
      console.error('Error fetching recent transactions:', err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-8">
        <Loader2 className="animate-spin text-secondary" size={24} />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {transactions.length > 0 ? (
        transactions.map((tx) => (
          <div key={tx.id} className="flex items-center justify-between p-3 rounded-lg bg-gray-50 dark:bg-white/5 hover:bg-gray-100 dark:hover:bg-white/10 transition-all group">
            <div className="flex items-center gap-3">
              <div className={`p-2 rounded-full ${tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade' ? 'bg-green-100 text-green-600 dark:bg-green-500/10' : 'bg-red-100 text-red-600 dark:bg-red-500/10'}`}>
                {tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade' ? <ArrowUpRight size={16} /> : <ArrowDownLeft size={16} />}
              </div>
              <div>
                <p className="text-[11px] font-black text-primary dark:text-gray-200 uppercase tracking-tight">{tx.description}</p>
                <p className="text-[9px] text-muted font-bold tracking-widest uppercase">{new Date(tx.transaction_date).toLocaleDateString(locale)}</p>
              </div>
            </div>
            <div className="text-right">
              <p className={`text-xs font-black ${tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade' ? 'text-green-600' : 'text-red-500'}`}>
                {tx.type === 'Yeni Alım' || tx.type === 'Yenileme' || tx.type === 'Upgrade' ? '+' : ''}{Number(tx.amount).toLocaleString(locale)} ₺
              </p>
              <p className={`text-[9px] font-black tracking-widest uppercase ${tx.status === 'completed' ? 'text-muted' : tx.status === 'pending' ? 'text-secondary' : 'text-red-400'}`}>
                {tx.status === 'completed' ? t('transaction_status_completed') : tx.status === 'pending' ? t('transaction_status_pending') : t('transaction_status_failed')}
              </p>
            </div>
          </div>
        ))
      ) : (
        <p className="text-center py-8 text-[10px] font-black text-muted tracking-widest uppercase italic">{t('transactions_empty')}</p>
      )}
      <button className="w-full py-2.5 text-[10px] font-black text-secondary hover:underline transition-all tracking-[0.2em] uppercase">
        {t('transactions_view_all')}
      </button>
    </div>
  );
};

export default RecentTransactions;
