
import React, { useState, useEffect } from 'react';
import {
    Save,
    Settings,
    Shield,
    Database,
    FileSpreadsheet,
    CreditCard,
    FileCheck,
    Cloud,
    Loader2,
    AlertCircle,
    CheckCircle2
} from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

const LiteSettingsPage: React.FC = () => {
    const { t } = useTranslation();
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    const [formData, setFormData] = useState({
        max_current_accounts: 50,
        max_daily_transactions: 20,
        max_daily_retail_sales: 50,
        report_days_limit: 30,
        is_bank_credit_active: false,
        is_check_promissory_active: false,
        is_cloud_backup_active: false,
        is_excel_export_active: false
    });

    useEffect(() => {
        fetchSettings();
    }, []);

    const fetchSettings = async () => {
        setLoading(true);
        try {
            const { data, error: fetchError } = await supabase
                .from('lite_settings')
                .select('*')
                .eq('id', 1)
                .single();

            if (fetchError) throw fetchError;
            if (data) {
                setFormData({
                    max_current_accounts: data.max_current_accounts,
                    max_daily_transactions: data.max_daily_transactions,
                    max_daily_retail_sales: data.max_daily_retail_sales,
                    report_days_limit: data.report_days_limit,
                    is_bank_credit_active: data.is_bank_credit_active,
                    is_check_promissory_active: data.is_check_promissory_active,
                    is_cloud_backup_active: data.is_cloud_backup_active,
                    is_excel_export_active: data.is_excel_export_active
                });
            }
        } catch (err) {
            console.error('Error fetching lite settings:', err);
            setError(t('lite_settings_fetch_error'));
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        setError(null);
        setSuccess(false);

        try {
            const { error: updateError } = await supabase
                .from('lite_settings')
                .update({
                    ...formData,
                    updated_at: new Date().toISOString()
                })
                .eq('id', 1);

            if (updateError) throw updateError;

            setSuccess(true);
            setTimeout(() => setSuccess(false), 3000);
        } catch (err) {
            console.error('Error saving lite settings:', err);
            setError(t('lite_settings_save_error'));
        } finally {
            setSaving(false);
        }
    };

    const ToggleSwitch = ({ label, checked, onChange, icon: Icon }: any) => (
        <label className="flex items-center justify-between p-4 bg-bg-light dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800 cursor-pointer hover:border-secondary/30 transition-all group">
            <div className="flex items-center gap-3">
                <div className="p-2 bg-white dark:bg-white/10 rounded-lg text-primary dark:text-white group-hover:scale-110 transition-transform">
                    <Icon size={18} />
                </div>
                <div>
                    <span className="text-[11px] font-black text-primary dark:text-gray-300 tracking-widest block uppercase mb-0.5">{label}</span>
                    <span className={`text-[10px] font-bold ${checked ? 'text-secondary' : 'text-muted'}`}>
                        {checked ? t('lite_settings_status_on') : t('lite_settings_status_off')}
                    </span>
                </div>
            </div>
            <div className="relative inline-flex items-center cursor-pointer">
                <input
                    type="checkbox"
                    className="sr-only peer"
                    checked={checked}
                    onChange={(e) => onChange(e.target.checked)}
                />
                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-secondary"></div>
            </div>
        </label>
    );

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="animate-spin text-secondary" size={40} />
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-20">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-xl font-black text-primary dark:text-white tracking-tight">{t('lite_settings_title')}</h2>
                    <p className="text-xs text-muted font-bold tracking-widest">{t('app_brand_primary')} {t('app_brand_secondary')} / {t('plan_lite')}</p>
                </div>
                <button
                    onClick={handleSave}
                    disabled={saving}
                    className="px-8 py-2.5 bg-secondary text-white rounded-lg text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95 flex items-center gap-2 disabled:opacity-50"
                >
                    {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                    {saving ? t('customer_edit_button_saving') : t('button_save')}
                </button>
            </div>

            {error && (
                <div className="p-4 bg-red-50 dark:bg-red-500/10 border border-red-100 dark:border-red-500/20 rounded-xl flex items-center gap-3 text-red-600 dark:text-red-400 text-xs font-black tracking-widest">
                    <AlertCircle size={18} /> {error}
                </div>
            )}

            {success && (
                <div className="p-4 bg-green-50 dark:bg-green-500/10 border border-green-100 dark:border-green-500/20 rounded-xl flex items-center gap-3 text-green-600 dark:text-green-400 text-xs font-black tracking-widest">
                    <CheckCircle2 size={18} /> {t('lite_settings_save_success')}
                </div>
            )}

            <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-10">
                {/* Limits Section */}
                <section className="space-y-6">
                    <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4 uppercase">
                        <Database size={14} /> {t('lite_settings_section_limits')}
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        <div>
                            <label className="block text-[10px] font-black text-muted tracking-widest mb-2 uppercase">{t('lite_settings_field_max_accounts')}</label>
                            <div className="relative">
                                <Shield size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
                                <input
                                    type="number"
                                    value={formData.max_current_accounts}
                                    onChange={(e) => setFormData({ ...formData, max_current_accounts: parseInt(e.target.value) || 0 })}
                                    className="w-full pl-12 pr-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-[10px] font-black text-muted tracking-widest mb-2 uppercase">{t('lite_settings_field_max_daily_trans')}</label>
                            <div className="relative">
                                <Database size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
                                <input
                                    type="number"
                                    value={formData.max_daily_transactions}
                                    onChange={(e) => setFormData({ ...formData, max_daily_transactions: parseInt(e.target.value) || 0 })}
                                    className="w-full pl-12 pr-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-[10px] font-black text-muted tracking-widest mb-2 uppercase">{t('lite_settings_field_max_daily_retail')}</label>
                            <div className="relative">
                                <CreditCard size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
                                <input
                                    type="number"
                                    value={formData.max_daily_retail_sales}
                                    onChange={(e) => setFormData({ ...formData, max_daily_retail_sales: parseInt(e.target.value) || 0 })}
                                    className="w-full pl-12 pr-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                        </div>
                        <div>
                            <label className="block text-[10px] font-black text-muted tracking-widest mb-2 uppercase">{t('lite_settings_field_report_limit')}</label>
                            <div className="relative">
                                <FileCheck size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted" />
                                <input
                                    type="number"
                                    value={formData.report_days_limit}
                                    onChange={(e) => setFormData({ ...formData, report_days_limit: parseInt(e.target.value) || 0 })}
                                    className="w-full pl-12 pr-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                        </div>
                    </div>
                </section>

                {/* Features Section */}
                <section className="space-y-6">
                    <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4 uppercase">
                        <Settings size={14} /> {t('lite_settings_section_features')}
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <ToggleSwitch
                            label={t('lite_settings_feature_bank')}
                            checked={formData.is_bank_credit_active}
                            onChange={(val: boolean) => setFormData({ ...formData, is_bank_credit_active: val })}
                            icon={CreditCard}
                        />
                        <ToggleSwitch
                            label={t('lite_settings_feature_check')}
                            checked={formData.is_check_promissory_active}
                            onChange={(val: boolean) => setFormData({ ...formData, is_check_promissory_active: val })}
                            icon={FileCheck}
                        />
                        <ToggleSwitch
                            label={t('lite_settings_feature_backup')}
                            checked={formData.is_cloud_backup_active}
                            onChange={(val: boolean) => setFormData({ ...formData, is_cloud_backup_active: val })}
                            icon={Cloud}
                        />
                        <ToggleSwitch
                            label={t('lite_settings_feature_excel')}
                            checked={formData.is_excel_export_active}
                            onChange={(val: boolean) => setFormData({ ...formData, is_excel_export_active: val })}
                            icon={FileSpreadsheet}
                        />
                    </div>
                </section>

                {/* Save Section Responsive Spacer */}
            </div>
        </div>
    );
};

export default LiteSettingsPage;
