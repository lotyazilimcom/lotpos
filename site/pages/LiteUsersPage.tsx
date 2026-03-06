
import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Search,
    Filter,
    Download,
    MapPin,
    MoreVertical,
    Settings,
    Loader2,
    Activity,
    RefreshCcw,
    UserPlus,
    Trash2,
    X,
    Database,
    Zap,
    Cloud,
    Globe
} from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

interface DemoUser {
    id: string;
    hardware_id: string;
    machine_name: string;
    ip_address: string;
    city: string;
    install_date: string;
    status?: 'active' | 'converted';
    plan?: 'LITE' | 'PRO';
    license_end_date?: string | null;
    last_activity: string;
    last_heartbeat: string;
    days_used: number;
    is_online: boolean;
    created_at: string;
}

interface DBConfig {
    mode: 'local' | 'hybrid' | 'cloud';
    supabase_url: string;
    supabase_anon_key: string;
}

const LiteUsersPage: React.FC = () => {
    const navigate = useNavigate();
    const { t, currentLang } = useTranslation();
    const locale = currentLang === 'ar' ? 'ar-SA' : currentLang === 'en' ? 'en-US' : 'tr-TR';
    const [users, setUsers] = useState<DemoUser[]>([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [fetchError, setFetchError] = useState<string | null>(null);
    const [searchTerm, setSearchTerm] = useState('');
    const [pageSize, setPageSize] = useState<number>(25);
    const [openMenuId, setOpenMenuId] = useState<string | null>(null);
    const dropdownRef = useRef<HTMLDivElement>(null);

    const [userToDelete, setUserToDelete] = useState<DemoUser | null>(null);
    const [deleteLoading, setDeleteLoading] = useState(false);

    // Database Config Modal State
    const [configUser, setConfigUser] = useState<DemoUser | null>(null);
    const [configData, setConfigData] = useState<DBConfig>({
        mode: 'local',
        supabase_url: '',
        supabase_anon_key: ''
    });
    const [configLoading, setConfigLoading] = useState(false);
    const [configSaving, setConfigSaving] = useState(false);

    const getPlan = (user: DemoUser) => (user.plan === 'PRO' ? 'PRO' : 'LITE');

    const handleOpenConfig = async (user: DemoUser) => {
        setOpenMenuId(null);
        setConfigUser(user);
        setConfigLoading(true);
        try {
            const { data, error } = await supabase
                .from('user_db_settings')
                .select('*')
                .eq('user_id', user.id)
                .maybeSingle();

            if (data) {
                setConfigData({
                    mode: data.mode as any,
                    supabase_url: data.supabase_url || '',
                    supabase_anon_key: data.supabase_anon_key || ''
                });
            } else {
                setConfigData({ mode: 'local', supabase_url: '', supabase_anon_key: '' });
            }
        } catch (err) {
            console.error('Error fetching db config:', err);
        } finally {
            setConfigLoading(false);
        }
    };

    const handleSaveConfig = async () => {
        if (!configUser) return;

        if ((configData.mode === 'cloud' || configData.mode === 'hybrid') && !configData.supabase_url) {
            alert(t('db_config_validation_error'));
            return;
        }

        setConfigSaving(true);
        try {
            const { error } = await supabase
                .from('user_db_settings')
                .upsert({
                    user_id: configUser.id,
                    mode: configData.mode,
                    supabase_url: configData.supabase_url,
                    supabase_anon_key: configData.supabase_anon_key,
                    updated_at: new Date().toISOString()
                }, { onConflict: 'user_id' });

            if (error) throw error;
            setConfigUser(null);
        } catch (err) {
            console.error('Error saving db config:', err);
            alert(t('lite_settings_save_error'));
        } finally {
            setConfigSaving(false);
        }
    };

    const handleDelete = async () => {
        if (!userToDelete) return;

        setDeleteLoading(true);
        try {
            const { error } = await supabase
                .from('program_deneme')
                .delete()
                .eq('id', userToDelete.id);

            if (error) throw error;

            setUsers(current => current.filter(u => u.id !== userToDelete.id));
            setUserToDelete(null);
        } catch (err) {
            console.error('Error deleting user:', err);
            alert(t('devices_delete_error'));
        } finally {
            setDeleteLoading(false);
        }
    };

    useEffect(() => {
        fetchUsers();

        const channel = supabase
            .channel('device_plan_updates')
            .on(
                'postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'program_deneme'
                },
                () => {
                    void fetchUsers(true);
                }
            )
            .on(
                'postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'licenses'
                },
                () => {
                    void fetchUsers(true);
                }
            )
            .subscribe();

        return () => {
            supabase.removeChannel(channel);
        };
    }, []);

    const fetchUsers = async (isSilent = false) => {
        if (!isSilent) setLoading(true);
        else setRefreshing(true);
        setFetchError(null);

        try {
            try {
                const { data, error } = await supabase
                    .from('lot_devices_v1')
                    .select('*')
                    .order('last_activity', { ascending: false });

                if (error) throw error;
                const visible = (data || []).filter((u: DemoUser) => u.status !== 'converted');
                setUsers(visible);
            } catch (err) {
                console.warn('lot_devices_v1 fetch failed, fallback to program_deneme:', err);

                const { data, error } = await supabase
                    .from('program_deneme')
                    .select('*')
                    .order('last_activity', { ascending: false });

                if (error) throw error;
                const visible = (data || [])
                    .filter((u: DemoUser) => u.status !== 'converted')
                    .map((u: any) => ({ ...u, plan: 'LITE' as const }));
                setUsers(visible);
            }
        } catch (err) {
            console.error('Error fetching devices:', err);
            setFetchError(t('devices_fetch_error'));
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    };

    // Filtered users
    const normalize = (value?: string | null) => (value || '').toLowerCase();
    const filteredUsers = users.filter(u =>
        normalize(u.hardware_id).includes(searchTerm.toLowerCase()) ||
        normalize(u.machine_name).includes(searchTerm.toLowerCase()) ||
        normalize(u.city).includes(searchTerm.toLowerCase()) ||
        normalize(u.ip_address).includes(searchTerm.toLowerCase())
    );

    // Close dropdown when clicking outside
    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
                setOpenMenuId(null);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="animate-spin text-secondary" size={40} />
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-in fade-in duration-500">
            {fetchError && (
                <div className="p-4 bg-red-50 dark:bg-red-500/10 border border-red-100 dark:border-red-500/20 rounded-xl text-red-600 dark:text-red-400 text-xs font-black tracking-widest">
                    {fetchError}
                </div>
            )}
            {/* Top Actions */}
            <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
                <div className="flex items-center gap-3 w-full sm:w-auto">
                    {/* Page Size Selector */}
                    <div className="relative">
                        <select
                            value={pageSize}
                            onChange={(e) => setPageSize(Number(e.target.value))}
                            className="h-10 pl-3 pr-8 bg-[#F8F9FA] dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-md text-[11px] font-black text-primary dark:text-gray-300 focus:outline-none focus:border-[#2C3E50]/20 transition-all appearance-none cursor-pointer"
                        >
                            <option value={10}>10</option>
                            <option value={25}>25</option>
                            <option value={50}>50</option>
                            <option value={100}>100</option>
                        </select>
                        <div className="absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none">
                            <svg className="w-3 h-3 text-[#95A5A6]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                            </svg>
                        </div>
                    </div>

                    {/* Search Input */}
                    <div className="relative flex-1 sm:w-80 group">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[#95A5A6] group-focus-within:text-[#2C3E50] transition-colors" size={16} />
                        <input
                            type="text"
                            placeholder={t('devices_search_placeholder')}
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full h-10 pl-10 pr-4 bg-[#F8F9FA] dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-md text-sm focus:outline-none focus:border-[#2C3E50]/20 transition-all font-bold"
                        />
                    </div>
                </div>

                <div className="flex items-center gap-2 w-full sm:w-auto">
                    <button
                        onClick={() => fetchUsers(true)}
                        disabled={refreshing}
                        className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-[#EA4335]/20 hover:border-[#EA4335] rounded-md text-[10px] font-black tracking-widest text-[#EA4335] transition-all shadow-sm active:scale-95 disabled:opacity-50"
                    >
                        <RefreshCcw size={14} className={refreshing ? 'animate-spin' : ''} /> {t('action_refresh')}
                    </button>
                    <button className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-md text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-all shadow-sm">
                        <Filter size={14} /> {t('action_filter')}
                    </button>
                    <button className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-md text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-all shadow-sm">
                        <Download size={14} /> {t('action_export')}
                    </button>
                </div>
            </div>

            {/* Desktop Table Section */}
            <div className="hidden md:block bg-white dark:bg-[#1A2530] rounded-xl shadow-sm border border-gray-100 dark:border-gray-800">
                <div className="overflow-x-visible">
                    <table className="w-full text-left">
                        <thead>
                            <tr className="border-b border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02]">
                                <th className="w-[180px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em]">{t('devices_table_hardware_device')}</th>
                                <th className="w-[150px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_ip_address')}</th>
                                <th className="w-[120px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_city')}</th>
                                <th className="w-[150px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_install_date')}</th>
                                <th className="w-[150px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_last_activity')}</th>
                                <th className="w-[80px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_days')}</th>
                                <th className="w-[150px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_plan')}</th>
                                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('devices_table_online')}</th>
                                <th className="w-[100px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-right">{t('devices_table_actions')}</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                            {filteredUsers.map((user) => (
                                <tr key={user.id} className="hover:bg-secondary/[0.02] dark:hover:bg-white/[0.02] transition-colors group text-primary dark:text-gray-300">
                                    <td className="px-6 py-5">
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-lg bg-gray-100 dark:bg-white/5 flex items-center justify-center text-secondary">
                                                <Activity size={16} />
                                            </div>
                                            <div className="flex flex-col">
                                                <p className="text-sm font-black tracking-wider">{user.hardware_id}</p>
                                                <p className="text-[10px] font-bold text-muted">{user.machine_name || t('common_unknown')}</p>
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-2 py-5 text-center text-[11px] font-bold">
                                        {user.ip_address}
                                    </td>
                                    <td className="px-2 py-5 text-center text-[11px] font-black tracking-wider">
                                        {user.city}
                                    </td>
                                    <td className="px-2 py-5 text-center text-[10px] font-black tracking-tighter">
                                        {new Date(user.install_date).toLocaleString(locale)}
                                    </td>
                                    <td className="px-2 py-5 text-center text-[10px] font-black tracking-tighter text-blue-500">
                                        {new Date(user.last_activity).toLocaleString(locale)}
                                    </td>
                                    <td className="px-2 py-5 text-center text-[11px] font-black">
                                        {user.days_used}
                                    </td>
                                    <td className="px-2 py-5 text-center">
                                        {(() => {
                                            const plan = getPlan(user);
                                            const badgeClass = plan === 'PRO'
                                                ? 'bg-green-500/10 text-green-500 border-green-500/20'
                                                : 'bg-[#EA4335]/10 text-[#EA4335] border-[#EA4335]/20';

                                            const endDate = user.license_end_date
                                                ? new Date(user.license_end_date).toLocaleDateString(locale)
                                                : null;

                                            return (
                                                <div className="flex flex-col items-center gap-1">
                                                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-[9px] font-black tracking-widest border ${badgeClass}`}>
                                                        {plan === 'PRO' ? t('plan_pro') : t('plan_lite')}
                                                    </span>
                                                    <span className="text-[8px] font-black tracking-widest text-muted opacity-60">
                                                        {plan === 'PRO' ? (endDate ?? '-') : t('plan_limited')}
                                                    </span>
                                                </div>
                                            );
                                        })()}
                                    </td>
                                    <td className="px-2 py-5 text-center">
                                        <span className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[9px] font-black tracking-widest ${user.is_online ? 'bg-green-500/10 text-green-500' : 'bg-gray-500/10 text-gray-400'
                                            }`}>
                                            <span className={`w-1.5 h-1.5 rounded-full animate-pulse-slow ${user.is_online ? 'bg-green-500' : 'bg-gray-400'}`} />
                                            {user.is_online ? t('status_active') : t('status_passive')}
                                        </span>
                                    </td>
                                    <td className="px-6 py-5 text-right">
                                        <div className="relative inline-block text-left">
                                            <button
                                                onClick={() => setOpenMenuId(openMenuId === user.id ? null : user.id)}
                                                className="p-2 text-muted hover:text-primary dark:hover:text-white transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-white/5"
                                            >
                                                <MoreVertical size={16} />
                                            </button>

                                            {openMenuId === user.id && (
                                                <div
                                                    ref={dropdownRef}
                                                    className={`absolute right-0 w-44 bg-white dark:bg-[#1A2530] border border-gray-100 dark:border-gray-800 rounded-lg shadow-xl z-[9999] overflow-hidden animate-in fade-in duration-200 ${
                                                        // Smart Positioning: Default downward, upward if it's the last row
                                                        filteredUsers.length > 2 && filteredUsers.findIndex(u => u.id === user.id) === filteredUsers.length - 1
                                                            ? 'bottom-full mb-1 slide-in-from-bottom-2'
                                                            : 'top-full mt-1 slide-in-from-top-2'
                                                        }`}
                                                >
                                                    <button
                                                        onClick={() => { navigate(`/dashboard/customers/new`, { state: { demoUser: user } }); setOpenMenuId(null); }}
                                                        className="flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-[#EA4335] hover:bg-[#EA4335]/5 transition-colors whitespace-nowrap"
                                                    >
                                                        <UserPlus size={14} /> {t('action_add_customer')}
                                                    </button>
                                                    <button
                                                        onClick={() => handleOpenConfig(user)}
                                                        className="flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors border-t border-gray-50 dark:border-gray-800/50 whitespace-nowrap"
                                                    >
                                                        <Settings size={14} /> {t('action_settings')}
                                                    </button>
                                                    <button
                                                        onClick={() => { setOpenMenuId(null); setUserToDelete(user); }}
                                                        className="flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-[#EA4335] hover:bg-[#EA4335]/5 transition-colors border-t border-gray-50 dark:border-gray-800/50 whitespace-nowrap"
                                                    >
                                                        <Trash2 size={14} /> {t('action_delete')}
                                                    </button>
                                                </div>
                                            )}
                                        </div>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
                <div className="px-6 py-3 border-t border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02] flex items-center justify-between">
                    <p className="text-[10px] text-muted font-black tracking-widest">{t('devices_total_prefix')} {filteredUsers.length} {t('devices_total_suffix')}</p>
                    <div className="flex gap-1">
                        <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_previous')}</button>
                        <button className="px-3 py-1 text-[10px] font-black rounded bg-primary text-white transition-all">1</button>
                        <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_next')}</button>
                    </div>
                </div>
            </div>

            {/* Mobile Card List Section */}
            <div className="block md:hidden space-y-4">
                {filteredUsers.map((user) => (
                    <div key={user.id} className="bg-white dark:bg-[#1A2530] rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm space-y-5">
                        <div className="flex items-start justify-between">
                            <div className="space-y-1">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('devices_table_hardware_device')}</p>
                                <h3 className="text-base font-black text-primary dark:text-white tracking-wider leading-tight">{user.hardware_id}</h3>
                                <p className="text-[11px] font-bold text-secondary italic">{user.machine_name}</p>
                            </div>
                            <span className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[9px] font-black tracking-widest ${user.is_online ? 'bg-green-500/10 text-green-500' : 'bg-gray-500/10 text-gray-400'}`}>
                                <span className={`w-1.5 h-1.5 rounded-full ${user.is_online ? 'bg-green-500' : 'bg-gray-400'}`} />
                                {user.is_online ? t('status_active') : t('status_passive')}
                            </span>
                        </div>

                        <div className="grid grid-cols-2 gap-4 pb-2">
                            <div className="space-y-2">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('devices_mobile_city_ip')}</p>
                                <div className="flex flex-col gap-1.5">
                                    <span className="text-[11px] font-black text-primary dark:text-gray-300 flex items-center gap-2">
                                        <MapPin size={12} className="text-muted" /> {user.city}
                                    </span>
                                    <span className="text-[11px] font-bold text-primary dark:text-gray-300">
                                        {user.ip_address}
                                    </span>
                                </div>
                            </div>
                            <div className="space-y-2">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('devices_mobile_plan_license')}</p>
                                <div className="space-y-1">
                                    {(() => {
                                        const plan = getPlan(user);
                                        const badgeClass = plan === 'PRO'
                                            ? 'bg-green-500/10 text-green-500 border-green-500/20'
                                            : 'bg-[#EA4335]/10 text-[#EA4335] border-[#EA4335]/20';

                                        const endDate = user.license_end_date
                                            ? new Date(user.license_end_date).toLocaleDateString(locale)
                                            : null;

                                        return (
                                            <div className="flex flex-col gap-1">
                                                <span className={`inline-flex items-center px-2 py-1 rounded-full text-[9px] font-black tracking-widest border w-fit ${badgeClass}`}>
                                                    {plan === 'PRO' ? t('plan_pro') : t('plan_lite')}
                                                </span>
                                                <p className="text-[10px] font-black text-muted tracking-tighter">
                                                    {plan === 'PRO' ? `${t('label_end')}: ${endDate ?? '-'}` : t('plan_limited_usage')}
                                                </p>
                                            </div>
                                        );
                                    })()}
                                    <p className="text-[10px] font-black text-secondary tracking-tighter">
                                        {new Date(user.last_activity).toLocaleDateString(locale)}
                                    </p>
                                </div>
                            </div>
                        </div>

                        <button
                            onClick={() => { navigate(`/dashboard/customers/new`, { state: { demoUser: user } }); }}
                            className="w-full h-12 bg-white dark:bg-bg-dark border border-[#EA4335]/20 text-[#EA4335] rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all"
                        >
                            <UserPlus size={16} /> {t('action_add_customer')}
                        </button>

                        <button
                            onClick={() => handleOpenConfig(user)}
                            className="w-full h-12 bg-secondary text-white rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-secondary/20"
                        >
                            <Settings size={16} /> {t('action_settings')}
                        </button>

                        <button
                            onClick={() => setUserToDelete(user)}
                            className="w-full h-12 bg-white dark:bg-bg-dark border border-[#EA4335]/20 text-[#EA4335] rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all"
                        >
                            <Trash2 size={16} /> {t('action_delete')}
                        </button>
                    </div>
                ))}
            </div>

            {/* Delete Confirmation Modal */}
            {userToDelete && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-primary/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setUserToDelete(null)}
                    />

                    <div className="relative w-full max-w-sm bg-white dark:bg-[#1A2530] rounded-2xl shadow-2xl overflow-hidden border border-gray-100 dark:border-gray-800 animate-in fade-in zoom-in duration-200">
                        <div className="p-6 text-center space-y-4">
                            <div className="w-16 h-16 bg-red-50 dark:bg-red-500/10 rounded-full flex items-center justify-center mx-auto text-[#EA4335]">
                                <Trash2 size={32} />
                            </div>

                            <div className="space-y-2">
                                <h3 className="text-lg font-black text-primary dark:text-white tracking-wider">{t('devices_delete_title')}</h3>
                                <p className="text-xs text-muted font-bold leading-relaxed px-4">
                                    {t('devices_delete_confirm')}
                                    <br />
                                    <span className="text-[10px] opacity-60 font-black tracking-widest mt-2 block">
                                        {t('label_id')}: {userToDelete.hardware_id}
                                    </span>
                                </p>
                            </div>

                            <div className="flex items-center gap-3 pt-2">
                                <button
                                    onClick={() => setUserToDelete(null)}
                                    className="flex-1 h-12 bg-[#F8F9FA] dark:bg-white/5 border border-gray-100 dark:border-gray-800 rounded-xl text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-colors"
                                >
                                    {t('button_cancel')}
                                </button>
                                <button
                                    onClick={handleDelete}
                                    disabled={deleteLoading}
                                    className="flex-1 h-12 bg-[#EA4335] text-white rounded-xl text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-red-500/20 active:scale-95 disabled:opacity-50"
                                >
                                    {deleteLoading ? t('action_deleting') : t('action_delete')}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
            {/* Database Config Modal */}
            {configUser && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-primary/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setConfigUser(null)}
                    />

                    <div className="relative w-full max-w-md bg-white dark:bg-[#1A2530] rounded-2xl shadow-2xl overflow-hidden border border-gray-100 dark:border-gray-800 animate-in fade-in zoom-in duration-200">
                        {/* Header */}
                        <div className="p-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
                            <div className="flex items-center gap-2 text-primary dark:text-white">
                                <Database className="text-secondary" size={20} />
                                <h3 className="font-black text-[11px] tracking-[0.2em] uppercase">{t('db_config_title')}</h3>
                            </div>
                            <button onClick={() => setConfigUser(null)} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-md text-muted transition-colors">
                                <X size={18} />
                            </button>
                        </div>

                        {/* Body */}
                        <div className="p-8">
                            {configLoading ? (
                                <div className="h-40 flex items-center justify-center">
                                    <Loader2 className="animate-spin text-secondary" size={30} />
                                </div>
                            ) : (
                                <div className="space-y-8">
                                    {/* Mode Selection */}
                                    <div className="space-y-3">
                                        <p className="text-[10px] font-black text-muted tracking-widest uppercase">{t('db_config_mode_select')}</p>
                                        <div className="grid grid-cols-1 gap-2">
                                            {[
                                                { id: 'local', icon: <Zap size={14} />, label: t('db_config_mode_local'), desc: t('db_config_mode_local_desc') },
                                                { id: 'hybrid', icon: <Globe size={14} />, label: t('db_config_mode_hybrid'), desc: t('db_config_mode_hybrid_desc') },
                                                { id: 'cloud', icon: <Cloud size={14} />, label: t('db_config_mode_cloud'), desc: t('db_config_mode_cloud_desc') }
                                            ].map((mode) => (
                                                <label
                                                    key={mode.id}
                                                    className={`flex items-center justify-between p-4 rounded-xl border-2 cursor-pointer transition-all ${configData.mode === mode.id
                                                        ? 'border-secondary bg-secondary/[0.02]'
                                                        : 'border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700'
                                                        }`}
                                                >
                                                    <div className="flex items-center gap-3">
                                                        <div className={`p-2 rounded-lg ${configData.mode === mode.id ? 'bg-secondary text-white' : 'bg-gray-100 dark:bg-white/5 text-muted'}`}>
                                                            {mode.icon}
                                                        </div>
                                                        <div>
                                                            <p className={`text-[11px] font-black tracking-widest uppercase ${configData.mode === mode.id ? 'text-secondary' : 'text-primary dark:text-gray-300'}`}>
                                                                {mode.label}
                                                            </p>
                                                            <p className="text-[9px] font-bold text-muted">{mode.desc}</p>
                                                        </div>
                                                    </div>
                                                    <input
                                                        type="radio"
                                                        name="db_mode"
                                                        className="hidden"
                                                        checked={configData.mode === mode.id}
                                                        onChange={() => setConfigData({ ...configData, mode: mode.id as any })}
                                                    />
                                                    <div className={`w-4 h-4 rounded-full border-2 flex items-center justify-center ${configData.mode === mode.id ? 'border-secondary' : 'border-gray-200 dark:border-gray-700'}`}>
                                                        {configData.mode === mode.id && <div className="w-2 h-2 rounded-full bg-secondary" />}
                                                    </div>
                                                </label>
                                            ))}
                                        </div>
                                    </div>

                                    {/* Conditional Fields */}
                                    {(configData.mode === 'hybrid' || configData.mode === 'cloud') && (
                                        <div className="space-y-4 animate-in fade-in slide-in-from-top-2 duration-300">
                                            <div className="space-y-2">
                                                <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('db_config_url_label')}</label>
                                                <input
                                                    type="text"
                                                    value={configData.supabase_url}
                                                    onChange={(e) => setConfigData({ ...configData, supabase_url: e.target.value })}
                                                    placeholder="https://xxx.supabase.co"
                                                    className="w-full h-11 px-4 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-xs font-bold focus:outline-none focus:border-secondary transition-all"
                                                />
                                            </div>
                                            <div className="space-y-2">
                                                <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('db_config_key_label')}</label>
                                                <input
                                                    type="password"
                                                    value={configData.supabase_anon_key}
                                                    onChange={(e) => setConfigData({ ...configData, supabase_anon_key: e.target.value })}
                                                    placeholder="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
                                                    className="w-full h-11 px-4 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-xs font-bold focus:outline-none focus:border-secondary transition-all"
                                                />
                                            </div>
                                        </div>
                                    )}

                                    {/* Footer */}
                                    <div className="flex items-center gap-3 pt-4">
                                        <button
                                            onClick={() => setConfigUser(null)}
                                            className="flex-1 h-12 bg-gray-50 dark:bg-white/5 border border-gray-100 dark:border-gray-800 rounded-xl text-[10px] font-black tracking-widest text-muted hover:text-primary transition-colors uppercase"
                                        >
                                            {t('button_cancel')}
                                        </button>
                                        <button
                                            onClick={handleSaveConfig}
                                            disabled={configSaving}
                                            className="flex-1 h-12 bg-secondary text-white rounded-xl text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95 disabled:opacity-50 uppercase flex items-center justify-center gap-2"
                                        >
                                            {configSaving ? <Loader2 size={16} className="animate-spin" /> : t('button_save')}
                                        </button>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default LiteUsersPage;
