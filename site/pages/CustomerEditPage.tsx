
import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import {
    ArrowLeft,
    Save,
    X,
    Building2,
    User,
    Phone,
    Mail,
    MapPin,
    FileText,
    ShieldCheck,
    Calendar,
    Layers,
    Loader2,
    AlertCircle,
    Cpu,
    Globe,
    CalendarDays,
    Clock,
    Lock
} from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import { generateLicenseToken } from '../lib/security';
import { useTranslation } from '@/hooks/useTranslation';

const PACKAGE_PRO_YEARLY = 'LOT PRO - Yıllık Plan';
const PACKAGE_BASIC_MONTHLY = 'LOT BASIC - Aylık Plan';
const PACKAGE_ULTIMATE = 'LOT ULTIMATE - Sınırsız';

const packageOptions = [
    { value: PACKAGE_PRO_YEARLY, labelKey: 'package_pro_yearly' },
    { value: PACKAGE_BASIC_MONTHLY, labelKey: 'package_basic_monthly' },
    { value: PACKAGE_ULTIMATE, labelKey: 'package_ultimate_unlimited' },
] as const;

const moduleOptions = [
    { value: 'Stok', labelKey: 'module_stock' },
    { value: 'Cari', labelKey: 'module_accounts' },
    { value: 'E-Fatura', labelKey: 'module_e_invoice' },
    { value: 'Perakende Satış', labelKey: 'module_retail_sales' },
    { value: 'Personel', labelKey: 'module_staff' },
    { value: 'Banka', labelKey: 'module_bank' },
    { value: 'Üretim', labelKey: 'module_production' },
    { value: 'Lojistik', labelKey: 'module_logistics' },
] as const;

const CustomerEditPage: React.FC = () => {
    const { t } = useTranslation();
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const location = useLocation();
    const isNew = !id || id === 'new';
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const [formData, setFormData] = useState({
        companyName: '',
        taxOffice: '',
        taxId: '',
        address: '',
        contactName: '',
        phone: '',
        email: '',
        city: '',
        status: 'active' as 'active' | 'passive',
        package: PACKAGE_PRO_YEARLY,
        licenseStart: new Date().toISOString().split('T')[0],
        licenseEnd: new Date(new Date().setFullYear(new Date().getFullYear() + 1)).toISOString().split('T')[0],
        modules: [] as string[],
        hardwareId: '',
        ipAddress: '',
        installationDate: '',
        trialDaysUsed: 0
    });

    useEffect(() => {
        if (!isNew && id) {
            fetchCustomerData();
        } else {
            // Check for demo conversion data
            const state = location.state as any;
            if (state?.demoUser) {
                const demo = state.demoUser;
                setFormData(prev => ({
                    ...prev,
                    companyName: demo.company_name || '',
                    contactName: demo.contact_name || '',
                    phone: demo.phone || '',
                    email: demo.email || '',
                    hardwareId: demo.hardware_id || '',
                    ipAddress: demo.ip_address || '',
                    city: demo.city || '',
                    installationDate: demo.install_date ? new Date(demo.install_date).toISOString().split('T')[0] : '',
                    trialDaysUsed: demo.days_used || 0
                }));
            }
            setLoading(false);
        }
    }, [id, isNew, location.state]);

    const fetchCustomerData = async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase
                .from('customers')
                .select(`
                    *,
                    licenses (*)
                `)
                .eq('id', id)
                .single();

            if (error) throw error;

            if (data) {
                const license = data.licenses?.[0];
                setFormData({
                    companyName: data.company_name || '',
                    taxOffice: data.tax_office || '',
                    taxId: data.tax_id || '',
                    address: data.address || '',
                    contactName: data.contact_name || '',
                    phone: data.phone || '',
                    email: data.email || '',
                    city: data.city || '',
                    status: data.status || 'active',
                    package: license?.package_name || PACKAGE_PRO_YEARLY,
                    licenseStart: license?.start_date || '',
                    licenseEnd: license?.end_date || '',
                    modules: license?.modules || [],
                    hardwareId: data.hardware_id || license?.hardware_id || '',
                    ipAddress: data.ip_address || '',
                    installationDate: data.installation_date ? new Date(data.installation_date).toISOString().split('T')[0] : '',
                    trialDaysUsed: data.trial_days_used || 0
                });
            }
        } catch (err) {
            console.error('Error fetching customer for edit:', err);
            setError(t('customer_edit_fetch_error'));
        } finally {
            setLoading(false);
        }
    };

    const handleSave = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        setError(null);

        try {
            const customerPayload = {
                company_name: formData.companyName,
                tax_office: formData.taxOffice,
                tax_id: formData.taxId,
                address: formData.address,
                contact_name: formData.contactName,
                phone: formData.phone,
                email: formData.email,
                city: formData.city,
                status: formData.status,
                hardware_id: formData.hardwareId,
                ip_address: formData.ipAddress,
                installation_date: formData.installationDate || null,
                trial_days_used: formData.trialDaysUsed
            };

            let customerId = id;

            if (isNew) {
                // INSERT Customer
                const { data: newCustomer, error: insertError } = await supabase
                    .from('customers')
                    .insert(customerPayload)
                    .select()
                    .single();

                if (insertError) throw insertError;
                customerId = newCustomer.id;

                // Create License for new customer
                const licensePayload = {
                    hardware_id: formData.hardwareId,
                    expiry_date: formData.licenseEnd,
                    modules: formData.modules
                };
                const licenseToken = await generateLicenseToken(licensePayload);

                const { error: licenseInsertError } = await supabase
                    .from('licenses')
                    .insert({
                        customer_id: customerId,
                        package_name: formData.package,
                        start_date: formData.licenseStart,
                        end_date: formData.licenseEnd,
                        modules: formData.modules,
                        license_key: licenseToken,
                        hardware_id: formData.hardwareId,
                        type: formData.package.includes('Yıllık') ? 'Yıllık' : 'Aylık'
                    });

                if (licenseInsertError) throw licenseInsertError;

                // If converted from demo, mark as converted
                const state = location.state as any;
                if (state?.demoUser?.id) {
                    const { error: convertError } = await supabase
                        .from('program_deneme')
                        .update({ status: 'converted' })
                        .eq('id', state.demoUser.id);

                    // Eski şemalarda `status` yoksa fallback olarak sil.
                    if (convertError) {
                        console.warn('program_deneme convert error:', convertError);
                        const { error: deleteError } = await supabase
                            .from('program_deneme')
                            .delete()
                            .eq('id', state.demoUser.id);
                        if (deleteError) console.warn('program_deneme delete error:', deleteError);
                    }
                }
            } else {
                // UPDATE Customer
                const { error: customerError } = await supabase
                    .from('customers')
                    .update(customerPayload)
                    .eq('id', id);

                if (customerError) throw customerError;

                // Update License
                const { data: licenseData } = await supabase
                    .from('licenses')
                    .select('id')
                    .eq('customer_id', id)
                    .limit(1)
                    .single();

                if (licenseData) {
                    const licensePayload = {
                        hardware_id: formData.hardwareId,
                        expiry_date: formData.licenseEnd,
                        modules: formData.modules
                    };
                    const licenseToken = await generateLicenseToken(licensePayload);

                    const { error: licenseError } = await supabase
                        .from('licenses')
                        .update({
                            package_name: formData.package,
                            start_date: formData.licenseStart,
                            end_date: formData.licenseEnd,
                            modules: formData.modules,
                            hardware_id: formData.hardwareId,
                            license_key: licenseToken
                        })
                        .eq('id', licenseData.id);

                    if (licenseError) throw licenseError;
                }
            }

            // DB-side lifecycle sync (best-effort): demo cleanup, passive/active, grace/trial
            const { error: syncError } = await supabase.rpc('lot_license_lifecycle_sync', {
                p_hardware_id: formData.hardwareId,
                p_machine_name: null
            });
            if (syncError) console.warn('lot_license_lifecycle_sync error:', syncError);

            // 3. Mark demo user as converted if applicable
            if (isNew && location.state?.demoUser) {
                // If it came from demo_users table
                await supabase
                    .from('demo_users')
                    .update({ status: 'converted' })
                    .eq('email', formData.email);
            }

            alert(t('customer_edit_save_success'));
            navigate(`/dashboard/customers/${customerId}`);
        } catch (err) {
            console.error('Error saving customer:', err);
            setError(t('customer_edit_save_error'));
        } finally {
            setSaving(false);
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
        <div className="max-w-5xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-20">
            {/* Header */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                    <button
                        onClick={() => navigate(`/dashboard/customers/${id}`)}
                        className="p-2 bg-white dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-lg text-[#95A5A6] hover:text-[#2C3E50] dark:hover:text-white transition-all shadow-sm"
                    >
                        <ArrowLeft size={20} />
                    </button>
                    <div>
                        <h2 className="text-xl font-black text-primary dark:text-white tracking-tight">{isNew ? t('customer_edit_title_new') : t('customer_edit_title_edit')}</h2>
                        <p className="text-xs text-muted font-bold tracking-widest">{isNew ? t('customer_edit_subtitle_new') : `${id?.slice(0, 8)} / ${formData.companyName}`}</p>
                    </div>
                </div>
                <div className="flex items-center gap-3">
                    <button
                        onClick={() => navigate(`/dashboard/customers/${id}`)}
                        className="px-6 py-2.5 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-lg text-[10px] font-black text-muted hover:text-primary dark:hover:text-white transition-all tracking-widest"
                    >
                        {t('button_cancel')}
                    </button>
                    <button
                        onClick={handleSave}
                        disabled={saving}
                        className="px-8 py-2.5 bg-secondary text-white rounded-lg text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95 flex items-center gap-2 disabled:opacity-50"
                    >
                        {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
                        {saving ? t('customer_edit_button_saving') : t('customer_edit_button_save')}
                    </button>
                </div>
            </div>

            {error && (
                <div className="p-4 bg-red-50 dark:bg-red-500/10 border border-red-100 dark:border-red-500/20 rounded-xl flex items-center gap-3 text-red-600 dark:text-red-400 text-xs font-black tracking-widest">
                    <AlertCircle size={18} /> {error}
                </div>
            )}

            <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* Identity & Contact Section */}
                <div className="space-y-6">
                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-6">
                        <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4">
                            <Building2 size={14} /> {t('customer_edit_section_corporate')}
                        </h3>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_company_name')}</label>
                                <input
                                    type="text"
                                    value={formData.companyName}
                                    onChange={(e) => setFormData({ ...formData, companyName: e.target.value })}
                                    className="w-full px-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_tax_office')}</label>
                                    <input
                                        type="text"
                                        value={formData.taxOffice}
                                        onChange={(e) => setFormData({ ...formData, taxOffice: e.target.value })}
                                        className="w-full px-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_tax_id')}</label>
                                    <input
                                        type="text"
                                        value={formData.taxId}
                                        onChange={(e) => setFormData({ ...formData, taxId: e.target.value })}
                                        className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors font-mono"
                                    />
                                </div>
                            </div>
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_invoice_address')}</label>
                                <textarea
                                    rows={3}
                                    value={formData.address}
                                    onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                                    className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-[11px] font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors resize-none"
                                />
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_city')}</label>
                                    <input
                                        type="text"
                                        value={formData.city}
                                        onChange={(e) => setFormData({ ...formData, city: e.target.value })}
                                        className="w-full px-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_status')}</label>
                                    <select
                                        value={formData.status}
                                        onChange={(e) => setFormData({ ...formData, status: e.target.value as 'active' | 'passive' })}
                                        className="w-full px-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    >
                                        <option value="active">{t('status_active')}</option>
                                        <option value="passive">{t('status_passive')}</option>
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-6">
                        <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4">
                            <Cpu size={14} /> {t('customer_edit_section_technical_trial')}
                        </h3>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_hardware_id')}</label>
                                <div className="relative group">
                                    <Lock size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-secondary transition-colors" />
                                    <input
                                        type="text"
                                        readOnly
                                        value={formData.hardwareId}
                                        placeholder={t('customer_field_hardware_id_placeholder')}
                                        className="w-full pl-12 pr-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-black text-secondary dark:text-secondary focus:outline-none transition-colors font-mono cursor-not-allowed"
                                    />
                                    <div className="absolute right-4 top-1/2 -translate-y-1/2 text-[9px] font-black text-secondary tracking-widest">
                                        {t('customer_field_locked')}
                                    </div>
                                </div>
                                <p className="mt-2 text-[9px] font-bold text-muted tracking-tighter">{t('customer_field_locked_help')}</p>
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_ip_address')}</label>
                                    <div className="relative group">
                                        <Globe size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-secondary transition-colors" />
                                        <input
                                            type="text"
                                            value={formData.ipAddress}
                                            onChange={(e) => setFormData({ ...formData, ipAddress: e.target.value })}
                                            className="w-full pl-10 pr-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors font-mono"
                                        />
                                    </div>
                                </div>
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_installation_date')}</label>
                                    <div className="relative group">
                                        <CalendarDays size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-secondary transition-colors" />
                                        <input
                                            type="date"
                                            value={formData.installationDate}
                                            onChange={(e) => setFormData({ ...formData, installationDate: e.target.value })}
                                            className="w-full pl-10 pr-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                        />
                                    </div>
                                </div>
                            </div>
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_trial_days_used')}</label>
                                <div className="relative group">
                                    <Clock size={14} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-secondary transition-colors" />
                                    <input
                                        type="number"
                                        value={formData.trialDaysUsed}
                                        onChange={(e) => setFormData({ ...formData, trialDaysUsed: parseInt(e.target.value) || 0 })}
                                        className="w-full pl-10 pr-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-6">
                        <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4">
                            <User size={14} /> {t('customer_edit_section_contact')}
                        </h3>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_contact_name')}</label>
                                <input
                                    type="text"
                                    value={formData.contactName}
                                    onChange={(e) => setFormData({ ...formData, contactName: e.target.value })}
                                    className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                />
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_phone')}</label>
                                    <input
                                        type="text"
                                        value={formData.phone}
                                        onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                                        className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors font-mono"
                                    />
                                </div>
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_email')}</label>
                                    <input
                                        type="email"
                                        value={formData.email}
                                        onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                        className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                {/* License Section */}
                <div className="space-y-6">
                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-6">
                        <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4">
                            <ShieldCheck size={14} /> {t('customer_edit_section_license')}
                        </h3>
                        <div className="space-y-4">
                            <div>
                                <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_package_plan')}</label>
                                <select
                                    value={formData.package}
                                    onChange={(e) => setFormData({ ...formData, package: e.target.value })}
                                    className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-black text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors h-12"
                                >
                                    {packageOptions.map((p) => (
                                        <option key={p.value} value={p.value}>{t(p.labelKey)}</option>
                                    ))}
                                </select>
                            </div>
                            <div className="grid grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_license_start')}</label>
                                    <input
                                        type="date"
                                        value={formData.licenseStart}
                                        onChange={(e) => setFormData({ ...formData, licenseStart: e.target.value })}
                                        className="w-full px-4 py-3 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-primary dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                                <div>
                                    <label className="block text-[10px] font-black text-muted tracking-widest mb-2">{t('customer_field_license_end')}</label>
                                    <input
                                        type="date"
                                        value={formData.licenseEnd}
                                        onChange={(e) => setFormData({ ...formData, licenseEnd: e.target.value })}
                                        className="w-full px-4 py-3 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold text-[#2C3E50] dark:text-white focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white dark:bg-[#1A2530] rounded-2xl p-8 border border-gray-100 dark:border-gray-800 shadow-sm space-y-6">
                        <h3 className="text-[10px] font-black text-muted tracking-[0.3em] flex items-center gap-2 border-b border-gray-50 dark:border-gray-800 pb-4">
                            <Layers size={14} /> {t('customer_edit_section_modules')}
                        </h3>
                        <div className="grid grid-cols-2 gap-3">
                            {moduleOptions.map((opt) => (
                                <label key={opt.value} className="flex items-center gap-3 p-3 bg-bg-light dark:bg-white/5 rounded-xl border border-gray-100 dark:border-gray-800 cursor-pointer hover:border-secondary/30 transition-all group">
                                    <input
                                        type="checkbox"
                                        checked={formData.modules.includes(opt.value)}
                                        onChange={(e) => {
                                            if (e.target.checked) {
                                                setFormData({ ...formData, modules: [...formData.modules, opt.value] });
                                            } else {
                                                setFormData({ ...formData, modules: formData.modules.filter(m => m !== opt.value) });
                                            }
                                        }}
                                        className="hidden"
                                    />
                                    <div className={`w-5 h-5 rounded border-2 flex items-center justify-center transition-all ${formData.modules.includes(opt.value) ? 'bg-secondary border-secondary' : 'bg-transparent border-gray-300 dark:border-gray-700'
                                        }`}>
                                        {formData.modules.includes(opt.value) && <X size={12} className="text-white transform rotate-45" />}
                                    </div>
                                    <span className="text-[11px] font-black text-primary dark:text-gray-300 tracking-widest">{t(opt.labelKey)}</span>
                                </label>
                            ))}
                        </div>
                    </div>
                </div>
            </form>
        </div>
    );
};

export default CustomerEditPage;
