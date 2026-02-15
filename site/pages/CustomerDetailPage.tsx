
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft,
    Building2,
    Edit3,
    Calendar,
    ShieldCheck,
    History,
    Info,
    MapPin,
    Phone,
    Mail,
    Hash,
    FileText,
    Clock,
    ExternalLink,
    RefreshCw,
    Clipboard,
    CheckCircle2,
    AlertCircle,
    ArrowUpCircle,
    CreditCard,
    Wallet,
    Coins,
    Receipt,
    Loader2,
    Cpu,
    Globe,
    CalendarDays,
    ShieldAlert,
    Activity
} from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

interface Transaction {
    id: string;
    transaction_date: string;
    type: string;
    description: string;
    payment_channel: string;
    amount: number;
    status: string;
}

interface License {
    id: string;
    package_name: string;
    type: 'Aylık' | 'Yıllık';
    start_date: string;
    end_date: string;
    hardware_id: string;
    license_key: string;
    modules: string[];
}

interface CustomerData {
    id: string;
    company_name: string;
    contact_name: string;
    status: 'active' | 'passive';
    created_at: string;
    tax_office: string;
    tax_id: string;
    address: string;
    phone: string;
    email: string;
    city: string;
    hardware_id: string;
    ip_address: string;
    installation_date: string;
    trial_days_used: number;
    last_heartbeat: string;
    licenses: License[];
    transactions: Transaction[];
}

const CustomerDetailPage: React.FC = () => {
    const { t, currentLang } = useTranslation();
    const locale = currentLang === 'ar' ? 'ar-SA' : currentLang === 'en' ? 'en-US' : 'tr-TR';
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState<'license' | 'history' | 'identity'>('license');
    const [customer, setCustomer] = useState<CustomerData | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        if (id) {
            fetchCustomerDetail();
        }
    }, [id]);

    const fetchCustomerDetail = async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase
                .from('customers')
                .select(`
                    *,
                    licenses (*),
                    transactions (*)
                `)
                .eq('id', id)
                .single();

            if (error) throw error;
            setCustomer(data);
        } catch (err) {
            console.error('Error fetching customer detail:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleKillSwitch = async () => {
        if (!customer || !customer.licenses[0]) return;

        if (!confirm(t('customer_detail_kill_switch_confirm'))) return;

        try {
            const { error } = await supabase
                .from('licenses')
                .update({ license_key: 'CANCELLED-' + Math.random().toString(36).substring(2, 6).toUpperCase() })
                .eq('customer_id', id);

            if (error) throw error;

            fetchCustomerDetail();
            alert(t('customer_detail_kill_switch_success'));
        } catch (err) {
            console.error('Kill switch error:', err);
            alert(t('customer_detail_action_error'));
        }
    };

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="animate-spin text-secondary" size={40} />
            </div>
        );
    }

    if (!customer) {
        return (
            <div className="h-[60vh] flex flex-col items-center justify-center gap-4">
                <AlertCircle className="text-red-400" size={48} />
                <p className="text-lg font-black text-primary dark:text-white tracking-widest">{t('customer_detail_not_found')}</p>
                <button onClick={() => navigate('/dashboard/customers')} className="text-secondary font-bold hover:underline">{t('button_return')}</button>
            </div>
        );
    }

    const activeLicense = customer.licenses?.[0];
    const daysRemaining = activeLicense ? Math.ceil((new Date(activeLicense.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24)) : 0;
    const totalDays = activeLicense ? Math.ceil((new Date(activeLicense.end_date).getTime() - new Date(activeLicense.start_date).getTime()) / (1000 * 60 * 60 * 24)) : 1;
    const progressPercent = activeLicense ? Math.min(100, Math.max(0, Math.round(((totalDays - daysRemaining) / totalDays) * 100))) : 0;

    return (
        <div className="space-y-6 animate-in fade-in slide-in-from-bottom-2 duration-500 pb-12">
            {/* Back Button & Title */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/dashboard/customers')}
                    className="p-2 bg-white dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-lg text-[#95A5A6] hover:text-[#2C3E50] dark:hover:text-white transition-all shadow-sm group"
                >
                    <ArrowLeft size={20} className="group-active:-translate-x-1 transition-transform" />
                </button>
                <div>
                    <h2 className="text-xl font-black text-primary dark:text-white tracking-tight">{t('customer_detail_title')}</h2>
                    <p className="text-xs text-muted font-bold tracking-widest">{customer.id.slice(0, 8)} / {customer.company_name}</p>
                </div>
            </div>

            {/* Header Summary Card */}
            <div className="bg-white dark:bg-[#1A2530] rounded-2xl shadow-sm border border-gray-100 dark:border-gray-800 overflow-hidden">
                <div className="p-6 md:p-8 flex flex-col md:flex-row items-center justify-between gap-6">
                    <div className="flex flex-col md:flex-row items-center gap-6 text-center md:text-left">
                        <div className="w-20 h-20 rounded-2xl bg-[#F8F9FA] dark:bg-white/5 border border-gray-100 dark:border-gray-800 flex items-center justify-center text-[#2C3E50] dark:text-gray-400 shadow-inner shrink-0 text-secondary">
                            <Building2 size={36} />
                        </div>
                        <div>
                            <div className="flex flex-col md:flex-row items-center gap-3 mb-2">
                                <h1 className="text-xl md:text-2xl font-black text-[#2C3E50] dark:text-white tracking-tight">{customer.company_name}</h1>
                                <span className={`px-3 py-1 border rounded-full text-[10px] font-black tracking-wider ${customer.status === 'active'
                                    ? 'bg-green-50 text-green-600 border-green-100 dark:bg-green-500/10 dark:text-green-400 dark:border-green-500/20'
                                    : 'bg-red-50 text-red-600 border-red-100 dark:bg-red-500/10 dark:text-red-400 dark:border-red-500/20'
                                    }`}>
                                    {customer.status === 'active' ? t('status_active') : t('status_passive')}
                                </span>
                            </div>
                            <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 text-muted text-[11px] md:text-xs font-bold tracking-widest">
                                <span className="flex items-center gap-1.5"><Calendar size={14} /> {t('label_record')}: {new Date(customer.created_at).toLocaleDateString(locale)}</span>
                                <span className="hidden sm:block w-1.5 h-1.5 rounded-full bg-gray-300" />
                                <span className="flex items-center gap-1.5"><Hash size={14} /> {t('label_id')}: {customer.id.slice(0, 8)}</span>
                            </div>
                        </div>
                    </div>
                    <button
                        onClick={() => navigate(`/dashboard/customers/${id}/edit`)}
                        className="w-full md:w-auto flex items-center justify-center gap-2 px-6 py-3 bg-secondary text-white rounded-xl text-xs font-black tracking-[0.2em] hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95"
                    >
                        <Edit3 size={16} /> {t('customer_detail_edit_profile')}
                    </button>
                </div>
            </div>

            {/* Tabs Control */}
            <div className="grid grid-cols-3 md:flex border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-[#1A2530] rounded-t-xl overflow-hidden">
                <button
                    onClick={() => setActiveTab('license')}
                    className={`flex flex-col md:flex-row items-center justify-center gap-1 md:gap-2 py-4 px-1 md:px-8 text-[9px] md:text-xs font-black tracking-[0.2em] transition-all relative ${activeTab === 'license' ? 'text-secondary bg-secondary/5 md:bg-transparent' : 'text-muted hover:text-primary dark:hover:text-white'
                        }`}
                >
                    <ShieldCheck size={16} className="md:size-[14px]" />
                    <span className="text-center">{t('customer_detail_tab_license')}</span>
                    {activeTab === 'license' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-secondary" />}
                </button>
                <button
                    onClick={() => setActiveTab('history')}
                    className={`flex flex-col md:flex-row items-center justify-center gap-1 md:gap-2 py-4 px-1 md:px-8 text-[9px] md:text-xs font-black tracking-[0.2em] transition-all relative ${activeTab === 'history' ? 'text-secondary bg-secondary/5 md:bg-transparent' : 'text-muted hover:text-primary dark:hover:text-white'
                        }`}
                >
                    <History size={16} className="md:size-[14px]" />
                    <span className="text-center">{t('customer_detail_tab_history')}</span>
                    {activeTab === 'history' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-secondary" />}
                </button>
                <button
                    onClick={() => setActiveTab('identity')}
                    className={`flex flex-col md:flex-row items-center justify-center gap-1 md:gap-2 py-4 px-1 md:px-8 text-[9px] md:text-xs font-black tracking-[0.2em] transition-all relative ${activeTab === 'identity' ? 'text-secondary bg-secondary/5 md:bg-transparent' : 'text-muted hover:text-primary dark:hover:text-white'
                        }`}
                >
                    <Info size={16} className="md:size-[14px]" />
                    <span className="text-center">{t('customer_detail_tab_profile')}</span>
                    {activeTab === 'identity' && <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-secondary" />}
                </button>
            </div>

            {/* Tab Content */}
            <div className="py-6">
                {activeTab === 'license' && (
                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 animate-in fade-in slide-in-from-right-4 duration-500">
                        {/* Package & Modules */}
                        <div className="lg:col-span-2 space-y-8">
                            <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-8">
                                <div className="flex items-center justify-between">
                                    <div className="space-y-1">
                                        <label className="text-[10px] font-black text-muted tracking-[0.3em]">{t('customer_detail_active_package')}</label>
                                        <h3 className="text-xl font-black text-[#2C3E50] dark:text-white tracking-tight">{activeLicense?.package_name || t('customer_detail_package_missing')}</h3>
                                    </div>
                                    <span className={`px-3 py-1 border rounded-full text-[10px] font-black tracking-wider ${activeLicense ? 'bg-green-50 text-green-600 border-green-100' : 'bg-gray-50 text-gray-400 border-gray-100'
                                        }`}>
                                        {activeLicense ? t('customer_detail_license_active') : t('customer_detail_no_license')}
                                    </span>
                                </div>

                                <div className="space-y-4">
                                    <label className="text-[10px] font-black text-muted tracking-[0.15em]">{t('customer_detail_active_modules')}</label>
                                    <div className="flex flex-wrap gap-1.5 md:gap-2">
                                        {activeLicense?.modules?.map(mod => (
                                            <div key={mod} className="flex items-center gap-1.5 px-2 py-1.5 md:px-3 md:py-2 bg-bg-light dark:bg-white/5 rounded-lg border border-gray-100 dark:border-gray-800 group hover:border-secondary/30 transition-colors">
                                                <div className="w-1.5 h-1.5 rounded-full bg-secondary" />
                                                <span className="text-[9px] md:text-[10px] font-black text-primary dark:text-gray-300 tracking-widest">{mod}</span>
                                            </div>
                                        )) || <p className="text-xs font-bold text-muted tracking-widest">{t('customer_detail_module_none')}</p>}
                                    </div>
                                </div>

                                <div className="pt-6 md:pt-8 border-t border-gray-100 dark:border-gray-800 flex flex-col sm:flex-row gap-6 md:gap-8">
                                    <div className="flex-1 space-y-3">
                                        <label className="text-[10px] font-black text-muted tracking-[0.15em]">{t('customer_detail_hardware_lock')}</label>
                                        <div className="flex items-center gap-2 md:gap-3">
                                            <div className="flex-1 p-3 bg-gray-50 dark:bg-black/20 rounded-lg border border-gray-200 dark:border-gray-800 text-[10px] md:text-xs font-black text-[#2C3E50] dark:text-gray-400 font-mono truncate">
                                                {activeLicense?.hardware_id || t('common_undefined')}
                                            </div>
                                            <button className="p-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg text-muted hover:text-primary transition-colors shadow-sm flex items-center gap-2 text-[10px] font-black tracking-widest group shrink-0">
                                                <RefreshCw size={14} className="group-active:rotate-180 transition-transform" /> <span className="hidden sm:inline">{t('action_reset')}</span>
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex flex-col sm:flex-row gap-3 md:gap-4">
                                <button className="w-full flex-1 flex items-center justify-center gap-3 px-8 py-4 bg-secondary text-white rounded-xl text-xs font-black tracking-[0.2em] hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95 leading-none h-14">
                                    <Calendar size={18} /> {t('customer_detail_extend_renew')}
                                </button>
                                <button className="w-full flex-1 flex items-center justify-center gap-3 px-8 py-4 bg-primary text-white rounded-xl text-xs font-black tracking-[0.2em] hover:opacity-90 transition-all shadow-lg shadow-primary/20 active:scale-95 leading-none h-14">
                                    <ArrowUpCircle size={18} /> {t('customer_detail_upgrade_package')}
                                </button>
                                <button
                                    onClick={handleKillSwitch}
                                    className="w-full sm:w-auto px-8 py-4 bg-secondary/10 hover:bg-secondary text-secondary hover:text-white transition-all text-[10px] font-black tracking-[0.2em] text-center border border-secondary/20 rounded-xl flex items-center justify-center gap-2"
                                >
                                    <ShieldAlert size={16} /> {t('customer_detail_cancel_license_kill_switch')}
                                </button>
                            </div>
                        </div>

                        {/* License & Progress Card */}
                        <div className="bg-[#2C3E50] rounded-2xl p-8 text-white space-y-8 shadow-xl relative overflow-hidden flex flex-col justify-between h-full min-h-[400px]">
                            <div className="absolute top-0 right-0 p-8 opacity-5">
                                <ShieldCheck size={180} />
                            </div>

                            <div className="space-y-6 relative z-10">
                                <h3 className="text-[10px] font-black text-white/40 tracking-[0.3em] flex items-center gap-2"><Clock size={14} /> {t('customer_detail_license_key_duration')}</h3>

                                <div className="space-y-3">
                                    <label className="text-[10px] font-black text-white/40 tracking-widest">{t('customer_detail_license_key')}</label>
                                    <div className="p-4 bg-white/5 rounded-xl border border-white/10 flex items-center justify-between">
                                        <code className="text-[11px] md:text-[13px] font-black tracking-[0.1em] md:tracking-[0.2em] font-mono truncate mr-2">{activeLicense?.license_key || t('common_masked_license_key')}</code>
                                        <button className="p-2 text-white/40 hover:text-white transition-colors shrink-0"><Clipboard size={16} /></button>
                                    </div>
                                </div>

                                <div className="pt-4 space-y-4">
                                    <div className="flex items-end gap-1.5">
                                        <span className="text-5xl font-black">{daysRemaining}</span>
                                        <span className="text-sm font-black text-white/40 mb-1.5 tracking-[0.15em]">{t('customer_detail_days_remaining')}</span>
                                    </div>
                                    <div className="space-y-2">
                                        <div className="h-2 w-full bg-white/10 rounded-full overflow-hidden">
                                            <div className="h-full bg-secondary rounded-full shadow-[0_0_12px_rgba(234,67,53,0.5)]" style={{ width: `${progressPercent}%` }} />
                                        </div>
                                        <div className="flex justify-between text-[10px] font-black tracking-widest text-white/30">
                                            <span>%{progressPercent} {t('customer_detail_progress_completed')}</span>
                                            <span>%{100 - progressPercent} {t('customer_detail_progress_remaining')}</span>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-4 relative z-10 pt-8 border-t border-white/10">
                                <div className="flex justify-between items-center text-xs font-black tracking-widest">
                                    <span className="text-white/30">{t('label_start')}</span>
                                    <span className="font-mono">{activeLicense ? new Date(activeLicense.start_date).toLocaleDateString(locale) : '-'}</span>
                                </div>
                                <div className="flex justify-between items-center text-xs font-black tracking-widest">
                                    <span className="text-white/30">{t('label_end')}</span>
                                    <span className="font-mono text-secondary">{activeLicense ? new Date(activeLicense.end_date).toLocaleDateString(locale) : '-'}</span>
                                </div>
                            </div>
                        </div>
                    </div>
                )}

                {activeTab === 'history' && (
                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden animate-in fade-in slide-in-from-right-4 duration-500">
                        {/* Desktop Table */}
                        <div className="hidden md:block overflow-x-auto">
                            <table className="w-full text-left">
	                                <thead>
	                                    <tr className="border-b border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02]">
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em]">{t('history_table_date')}</th>
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em]">{t('history_table_type')}</th>
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em]">{t('history_table_description')}</th>
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em]">{t('history_table_payment_channel')}</th>
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em] text-right">{t('history_table_amount')}</th>
	                                        <th className="px-6 py-5 text-[10px] font-black text-primary dark:text-muted tracking-[0.2em] text-center">{t('history_table_document')}</th>
	                                    </tr>
	                                </thead>
                                <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                                    {customer.transactions?.map((tx) => (
                                        <tr key={tx.id} className="hover:bg-gray-50 dark:hover:bg-white/[0.01] transition-colors group">
                                            <td className="px-6 py-6 text-[10px] font-black text-[#2C3E50] dark:text-gray-400 font-mono">
                                                {new Date(tx.transaction_date).toLocaleDateString(locale)}
                                            </td>
                                            <td className="px-6 py-6">
                                                <div className="flex items-center gap-3">
                                                    <div className={`p-2 rounded-lg ${tx.status === 'completed' ? 'bg-green-50 text-green-600 dark:bg-green-500/10' : 'bg-amber-50 text-amber-600 dark:bg-amber-500/10'}`}>
                                                        {tx.status === 'completed' ? <CheckCircle2 size={14} /> : <AlertCircle size={14} />}
                                                    </div>
                                                    <span className="text-[10px] font-black tracking-widest text-primary dark:text-gray-300">{tx.type}</span>
                                                </div>
                                            </td>
                                            <td className="px-6 py-6 text-[11px] font-bold text-[#95A5A6] dark:text-gray-500 uppercase">{tx.description}</td>
                                            <td className="px-6 py-6 transition-transform group-hover:translate-x-1">
                                                <div className="flex items-center gap-2">
                                                    <Wallet size={12} className="text-[#95A5A6]" />
                                                    <span className="text-[10px] font-black text-primary dark:text-gray-400 uppercase">{tx.payment_channel}</span>
                                                </div>
                                            </td>
                                            <td className="px-6 py-6 text-right">
                                                <span className="text-sm font-black text-[#2C3E50] dark:text-gray-200">{tx.amount.toLocaleString(locale)} ₺</span>
                                            </td>
                                            <td className="px-6 py-6 text-center">
                                                <button className="p-2 text-muted hover:text-secondary transition-colors"><Receipt size={16} /></button>
                                            </td>
                                        </tr>
                                    )) || (
                                            <tr>
                                                <td colSpan={6} className="px-6 py-12 text-center text-[10px] font-black text-muted tracking-widest uppercase">{t('history_empty')}</td>
                                            </tr>
                                        )}
                                </tbody>
                            </table>
                        </div>

                        {/* Mobile History */}
                        <div className="md:hidden divide-y divide-gray-100 dark:divide-gray-800">
                            {customer.transactions?.map((tx) => (
                                <div key={tx.id} className="p-5 space-y-4">
                                    <div className="flex items-center justify-between">
                                        <span className="text-[10px] font-black text-muted font-mono">{new Date(tx.transaction_date).toLocaleDateString(locale)}</span>
                                        <div className={`px-2 py-1 rounded text-[9px] font-black tracking-widest ${tx.status === 'completed' ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'}`}>
                                            {tx.status === 'completed' ? t('transaction_status_completed') : t('transaction_status_pending')}
                                        </div>
                                    </div>
                                    <div className="flex items-start gap-4">
                                        <div className={`p-2.5 rounded-full shrink-0 ${tx.status === 'completed' ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'}`}>
                                            {tx.status === 'completed' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
                                        </div>
                                        <div className="flex-1">
                                            <p className="text-xs font-black text-primary dark:text-white leading-tight tracking-tight">{tx.description}</p>
                                            <div className="flex items-center gap-2 mt-2">
                                                <Wallet size={12} className="text-muted" />
                                                <span className="text-[10px] font-black text-muted uppercase tracking-widest">{tx.payment_channel}</span>
                                            </div>
                                        </div>
                                        <div className="text-right shrink-0">
                                            <p className="text-sm font-black text-primary dark:text-white">{tx.amount.toLocaleString(locale)} ₺</p>
                                            <button className="mt-2 p-2 text-secondary bg-secondary/5 rounded-lg">
                                                <Receipt size={16} />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                )}

                {activeTab === 'identity' && (
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 animate-in fade-in slide-in-from-right-4 duration-500">
	                        {/* Tax Info */}
	                        <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-6 md:p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-8">
	                            <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2"><FileText size={14} /> {t('customer_detail_section_tax_info')}</h3>
	                            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_tax_office')}</label>
	                                    <p className="text-sm font-black text-[#2C3E50] dark:text-white uppercase">{customer.tax_office || '-'}</p>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_tax_id')}</label>
	                                    <p className="text-sm font-black text-[#2C3E50] dark:text-white font-mono">{customer.tax_id || '-'}</p>
	                                </div>
	                                <div className="md:col-span-2">
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_invoice_address')}</label>
	                                    <div className="p-4 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-dashed border-gray-200 dark:border-gray-700 flex gap-3">
	                                        <MapPin size={16} className="text-[#95A5A6] shrink-0 mt-0.5" />
	                                        <p className="text-[11px] font-bold text-[#2C3E50] dark:text-gray-300 leading-relaxed font-mono">{customer.address || t('customer_detail_address_missing')}</p>
	                                    </div>
	                                </div>
	                            </div>
	                        </div>

	                        {/* Contact Info */}
	                        <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-8">
	                            <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2"><Phone size={14} /> {t('customer_edit_section_contact')}</h3>
	                            <div className="space-y-6">
	                                <div className="flex items-center gap-4 p-4 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
                                    <div className="w-10 h-10 rounded-full bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 flex items-center justify-center text-secondary font-black text-xs shadow-sm uppercase">
                                        {customer.contact_name.split(' ').map(n => n[0]).join('')}
	                                    </div>
	                                    <div>
	                                        <label className="block text-[9px] font-black text-muted tracking-widest">{t('customer_field_contact_name')}</label>
	                                        <p className="text-sm font-black text-[#2C3E50] dark:text-white uppercase">{customer.contact_name}</p>
	                                    </div>
	                                </div>
	                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div className="p-4 bg-white dark:bg-bg-dark border border-gray-100 dark:border-gray-800 rounded-xl flex items-center gap-4 hover:border-secondary/30 transition-colors">
	                                        <div className="w-10 h-10 rounded-lg bg-[#F8F9FA] dark:bg-white/5 flex items-center justify-center text-[#95A5A6]"><Phone size={18} /></div>
	                                        <div>
	                                            <label className="block text-[9px] font-black text-muted tracking-widest uppercase">{t('customer_field_phone')}</label>
	                                            <p className="text-sm font-black text-[#2C3E50] dark:text-white font-mono">{customer.phone}</p>
	                                        </div>
	                                    </div>
	                                    <div className="p-4 bg-white dark:bg-bg-dark border border-gray-100 dark:border-gray-800 rounded-xl flex items-center gap-4 hover:border-secondary/30 transition-colors">
	                                        <div className="w-10 h-10 rounded-lg bg-[#F8F9FA] dark:bg-white/5 flex items-center justify-center text-[#95A5A6]"><Mail size={18} /></div>
	                                        <div>
	                                            <label className="block text-[9px] font-black text-muted tracking-widest uppercase">{t('customer_field_email')}</label>
	                                            <p className="text-sm font-black text-[#2C3E50] dark:text-white truncate uppercase">{customer.email}</p>
	                                        </div>
	                                    </div>
	                                </div>
	                            </div>
	                        </div>

	                        {/* Technical & Trial Info */}
	                        <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-6 md:p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-8 lg:col-span-2">
	                            <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2"><Cpu size={14} /> {t('customer_detail_section_technical_tracking_trial')}</h3>
	                            <div className="grid grid-cols-1 md:grid-cols-4 gap-6 md:gap-8">
	                                <div className="md:col-span-2">
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_detail_hardware_lock')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <Cpu size={14} className="text-secondary" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white font-mono truncate">{customer.hardware_id || t('common_undefined')}</p>
	                                    </div>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_ip_address')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <Globe size={14} className="text-blue-500" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white font-mono">{customer.ip_address || '-'}</p>
	                                    </div>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_city')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <MapPin size={14} className="text-red-500" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white uppercase">{customer.city || '-'}</p>
	                                    </div>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_installation_date')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <CalendarDays size={14} className="text-amber-500" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white">{customer.installation_date ? new Date(customer.installation_date).toLocaleDateString(locale) : '-'}</p>
	                                    </div>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_detail_trial_period')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <Clock size={14} className="text-secondary" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white">{customer.trial_days_used || 0} {t('label_day')}</p>
	                                    </div>
	                                </div>
	                                <div>
	                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_detail_last_heartbeat')}</label>
	                                    <div className="flex items-center gap-3 p-3 bg-[#F8F9FA] dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800">
	                                        <Activity size={14} className="text-green-500" />
	                                        <p className="text-xs font-black text-[#2C3E50] dark:text-white font-mono">
	                                            {customer.last_heartbeat ? new Date(customer.last_heartbeat).toLocaleString(locale) : t('common_none')}
	                                        </p>
	                                    </div>
	                                </div>
	                            </div>
	                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

export default CustomerDetailPage;
