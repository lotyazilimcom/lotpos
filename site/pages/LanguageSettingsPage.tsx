import React, { useState, useEffect, useRef } from 'react';
import {
    Globe,
    Plus,
    Trash2,
    Edit2,
    Check,
    Search,
    Download,
    Upload,
    MoreVertical,
    ChevronRight,
    Loader2,
    Languages,
    FileJson,
    CheckCircle2,
    AlertCircle,
    X
} from 'lucide-react';
import { supabase } from '@/lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

interface Language {
    id: string;
    name: string;
    short_code: string;
    locale_code: string;
    direction: 'ltr' | 'rtl';
    is_default: boolean;
    is_active: boolean;
    is_system: boolean;
    sort_order: number;
    translations: any;
}

const LanguageSettingsPage: React.FC = () => {
    const { t, setLanguage } = useTranslation();
    const [languages, setLanguages] = useState<Language[]>([]);
    const [loading, setLoading] = useState(true);
    const [searchTerm, setSearchTerm] = useState('');
    const [pageSize, setPageSize] = useState<number>(25);
    const [saving, setSaving] = useState(false);
    const [openMenuId, setOpenMenuId] = useState<string | null>(null);
    const dropdownRef = useRef<HTMLDivElement>(null);

    // Modal States
    const [isAddModalOpen, setIsAddModalOpen] = useState(false);
    const [isImportModalOpen, setIsImportModalOpen] = useState(false);
    const [editingId, setEditingId] = useState<string | null>(null);

    // Form State
    const [formData, setFormData] = useState({
        name: '',
        short_code: '',
        locale_code: '',
        sort_order: 0,
        direction: 'ltr' as 'ltr' | 'rtl',
        is_active: true
    });

    useEffect(() => {
        fetchLanguages();
    }, []);

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

    const fetchLanguages = async () => {
        setLoading(true);
        try {
            const { data, error } = await supabase
                .from('languages')
                .select('*')
                .order('sort_order', { ascending: true });

            if (error) throw error;
            setLanguages(data || []);
        } catch (err) {
            console.error('Error fetching languages:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleSaveLanguage = async (e: React.FormEvent) => {
        e.preventDefault();
        setSaving(true);
        try {
            if (editingId) {
                // Update existing
                const { error } = await supabase
                    .from('languages')
                    .update(formData)
                    .eq('id', editingId);

                if (error) throw error;
                setLanguages(languages.map(l => l.id === editingId ? { ...l, ...formData, id: editingId } : l));
            } else {
                // Insert new
                const { data, error } = await supabase
                    .from('languages')
                    .insert([formData])
                    .select();

                if (error) throw error;
                setLanguages([...languages, data[0]]);
            }

            setFormData({
                name: '',
                short_code: '',
                locale_code: '',
                sort_order: 0,
                direction: 'ltr',
                is_active: true
            });
            setEditingId(null);
            setIsAddModalOpen(false);
        } catch (err) {
            console.error('Error saving language:', err);
        } finally {
            setSaving(false);
        }
    };

    const openEditModal = (lang: Language) => {
        setEditingId(lang.id);
        setFormData({
            name: lang.name,
            short_code: lang.short_code,
            locale_code: lang.locale_code,
            sort_order: lang.sort_order,
            direction: lang.direction,
            is_active: lang.is_active
        });
        setIsAddModalOpen(true);
    };

    const openAddModal = () => {
        setEditingId(null);
        setFormData({
            name: '',
            short_code: '',
            locale_code: '',
            sort_order: 0,
            direction: 'ltr',
            is_active: true
        });
        setIsAddModalOpen(true);
    };

    const toggleStatus = async (lang: Language) => {
        if (lang.is_default) return;
        const newStatus = !lang.is_active;
        try {
            const { error } = await supabase
                .from('languages')
                .update({ is_active: newStatus })
                .eq('id', lang.id);

            if (error) throw error;
            setLanguages(languages.map(l => l.id === lang.id ? { ...l, is_active: newStatus } : l));
        } catch (err) {
            console.error('Error toggling status:', err);
        }
    };

    const setDefault = async (lang: Language) => {
        try {
            // First, remove default from all
            await supabase.from('languages').update({ is_default: false }).neq('id', lang.id);

            // Set this one as default
            const { error } = await supabase
                .from('languages')
                .update({ is_default: true })
                .eq('id', lang.id);

            if (error) throw error;
            setLanguages(languages.map(l => ({ ...l, is_default: l.id === lang.id })));

            // Immediately switch application language
            setLanguage(lang.short_code);
        } catch (err) {
            console.error('Error setting default:', err);
        }
    };

    const filteredLanguages = languages.filter(l =>
        (l.name || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        (l.short_code || '').toLowerCase().includes(searchTerm.toLowerCase())
    );

    if (loading) {
        return (
            <div className="h-[60vh] flex items-center justify-center">
                <Loader2 className="animate-spin text-secondary" size={40} />
            </div>
        );
    }

    return (
        <div className="space-y-6 animate-in fade-in duration-500">
            {/* Top Header Section */}
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
                            placeholder={t('search_placeholder')}
                            value={searchTerm}
                            onChange={(e) => setSearchTerm(e.target.value)}
                            className="w-full h-10 pl-10 pr-4 bg-[#F8F9FA] dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-md text-sm focus:outline-none focus:border-[#2C3E50]/20 transition-all font-bold"
                        />
                    </div>
                </div>

                <div className="flex items-center gap-2 w-full sm:w-auto">
                    <button
                        onClick={() => setIsImportModalOpen(true)}
                        className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-md text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-all shadow-sm"
                    >
                        <Upload size={14} /> {t('import_language')}
                    </button>
                    <button
                        onClick={openAddModal}
                        className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-6 h-10 bg-secondary text-white rounded-md text-[10px] font-black tracking-[0.15em] hover:opacity-90 transition-all shadow-md shadow-secondary/10 active:scale-95"
                    >
                        <Plus size={16} /> {t('add_language')}
                    </button>
                </div>
            </div>

            {/* Desktop Table Section */}
            <div className="hidden md:block bg-white dark:bg-[#1A2530] rounded-xl shadow-sm border border-gray-100 dark:border-gray-800">
                <div className="overflow-x-visible">
                    <table className="w-full text-left">
                        <thead>
                            <tr className="border-b border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02]">
                                <th className="w-[80px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('table_header_order')}</th>
                                <th className="w-[200px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em]">{t('table_header_name')}</th>
                                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('table_header_code')}</th>
                                <th className="w-[120px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('table_header_default')}</th>
                                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('table_header_status')}</th>
                                <th className="w-[180px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('table_header_translations')}</th>
                                <th className="w-[100px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-right">{t('table_header_actions')}</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
                            {filteredLanguages.map((lang, index) => (
                                <tr key={lang.id} className="hover:bg-secondary/[0.02] dark:hover:bg-white/[0.02] transition-colors group text-primary dark:text-gray-300">
                                    <td className="px-6 py-5 text-center text-[11px] font-bold">{lang.sort_order || index + 1}</td>
                                    <td className="px-6 py-5">
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-lg bg-gray-100 dark:bg-white/5 flex items-center justify-center text-secondary">
                                                <Globe size={16} />
                                            </div>
                                            <div className="flex flex-col">
                                                <p className="text-sm font-black tracking-wider">{lang.name}</p>
                                                {lang.direction === 'rtl' && (
                                                    <span className="text-[8px] font-black tracking-widest text-amber-600">{t('rtl_badge')}</span>
                                                )}
                                            </div>
                                        </div>
                                    </td>
                                    <td className="px-2 py-5 text-center text-[11px] font-black tracking-wider uppercase">{lang.short_code}</td>
                                    <td className="px-2 py-5 text-center">
                                        <button
                                            onClick={() => setDefault(lang)}
                                            className={`p-1.5 rounded-full transition-all ${lang.is_default ? 'bg-green-500 text-white shadow-lg shadow-green-500/20' : 'bg-gray-100 dark:bg-white/5 text-muted hover:text-primary dark:hover:text-white'}`}
                                        >
                                            <CheckCircle2 size={16} />
                                        </button>
                                    </td>
                                    <td className="px-2 py-5 text-center">
                                        <span className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[9px] font-black tracking-widest ${lang.is_active ? 'bg-green-500/10 text-green-500' : 'bg-gray-500/10 text-gray-400'
                                            }`}>
                                            <span className={`w-1.5 h-1.5 rounded-full animate-pulse-slow ${lang.is_active ? 'bg-green-500' : 'bg-gray-400'}`} />
                                            {lang.is_active ? t('status_active') : t('status_passive')}
                                        </span>
                                    </td>
                                    <td className="px-2 py-5 text-center">
                                        <div className="flex items-center justify-center gap-2">
                                            <button
                                                onClick={() => openEditModal(lang)}
                                                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-blue-50 dark:bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-100 dark:border-blue-500/20 rounded-lg text-[9px] font-black tracking-widest hover:bg-blue-100 dark:hover:bg-blue-500/20 transition-all active:scale-95"
                                            >
                                                <Languages size={12} /> {t('action_edit')}
                                            </button>
                                            <button
                                                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gray-50 dark:bg-white/5 text-primary dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-lg text-[9px] font-black tracking-widest hover:bg-gray-100 dark:hover:bg-white/10 transition-all active:scale-95"
                                            >
                                                <Download size={12} /> {t('action_export')}
                                            </button>
                                        </div>
                                    </td>
                                    <td className="px-6 py-5 text-right">
                                        <div className="relative inline-block text-left">
                                            <button
                                                onClick={() => setOpenMenuId(openMenuId === lang.id ? null : lang.id)}
                                                className="p-2 text-muted hover:text-primary dark:hover:text-white transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-white/5"
                                            >
                                                <MoreVertical size={16} />
                                            </button>

                                            {openMenuId === lang.id && (
                                                <div
                                                    ref={dropdownRef}
                                                    className={`absolute right-0 w-44 bg-white dark:bg-[#1A2530] border border-gray-100 dark:border-gray-800 rounded-lg shadow-xl z-[9999] overflow-hidden animate-in fade-in duration-200 ${filteredLanguages.length > 2 && filteredLanguages.findIndex(l => l.id === lang.id) === filteredLanguages.length - 1
                                                        ? 'bottom-full mb-1 slide-in-from-bottom-2'
                                                        : 'top-full mt-1 slide-in-from-top-2'
                                                        }`}
                                                >
                                                    <button
                                                        onClick={() => { setDefault(lang); setOpenMenuId(null); }}
                                                        className="flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors whitespace-nowrap"
                                                    >
                                                        <CheckCircle2 size={14} className="text-green-500" /> {t('action_make_default')}
                                                    </button>
                                                    <button
                                                        onClick={() => { toggleStatus(lang); setOpenMenuId(null); }}
                                                        disabled={lang.is_default}
                                                        className={`flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors border-t border-gray-50 dark:border-gray-800/50 whitespace-nowrap ${lang.is_default ? 'opacity-50 cursor-not-allowed' : ''}`}
                                                    >
                                                        <Check size={14} className="text-secondary" /> {lang.is_active ? t('action_make_passive') : t('action_make_active')}
                                                    </button>
                                                    <button
                                                        onClick={() => { openEditModal(lang); setOpenMenuId(null); }}
                                                        className="flex items-center gap-2 w-full px-4 py-3 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors border-t border-gray-50 dark:border-gray-800/50 whitespace-nowrap"
                                                    >
                                                        <Edit2 size={14} /> {t('action_edit')}
                                                    </button>
                                                    <button
                                                        onClick={() => setOpenMenuId(null)}
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
                    <p className="text-[10px] text-muted font-black tracking-widest">{t('total_records_prefix')} {filteredLanguages.length} {t('total_records_suffix')}</p>
                    <div className="flex gap-1">
                        <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_previous')}</button>
                        <button className="px-3 py-1 text-[10px] font-black rounded bg-primary text-white transition-all">1</button>
                        <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_next')}</button>
                    </div>
                </div>
            </div>

            {/* Mobile Card List Section */}
            <div className="block md:hidden space-y-4">
                {filteredLanguages.map((lang) => (
                    <div key={lang.id} className="bg-white dark:bg-[#1A2530] rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm space-y-5">
                        <div className="flex items-start justify-between">
                            <div className="space-y-1">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('mobile_label_name_code')}</p>
                                <h3 className="text-base font-black text-primary dark:text-white tracking-wider leading-tight">{lang.name}</h3>
                                <p className="text-[11px] font-bold text-secondary italic uppercase">{lang.short_code}</p>
                            </div>
                            <span className={`inline-flex items-center gap-1.5 px-2 py-1 rounded-full text-[9px] font-black tracking-widest ${lang.is_active ? 'bg-green-500/10 text-green-500' : 'bg-gray-500/10 text-gray-400'}`}>
                                <span className={`w-1.5 h-1.5 rounded-full ${lang.is_active ? 'bg-green-500' : 'bg-gray-400'}`} />
                                {lang.is_active ? t('status_active') : t('status_passive')}
                            </span>
                        </div>

                        <div className="grid grid-cols-2 gap-4 pb-2">
                            <div className="space-y-2">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('mobile_label_default')}</p>
                                <span className="text-[11px] font-black text-primary dark:text-gray-300 flex items-center gap-2">
                                    <CheckCircle2 size={12} className={lang.is_default ? 'text-green-500' : 'text-muted'} />
                                    {lang.is_default ? t('yes') : t('no')}
                                </span>
                            </div>
                            <div className="space-y-2">
                                <p className="text-[9px] font-black text-muted tracking-widest opacity-40">{t('mobile_label_direction')}</p>
                                <span className="text-[11px] font-black text-primary dark:text-gray-300">
                                    {lang.direction === 'rtl' ? t('direction_rtl') : t('direction_ltr')}
                                </span>
                            </div>
                        </div>

                        <button
                            onClick={() => setDefault(lang)}
                            className="w-full h-12 bg-white dark:bg-bg-dark border border-secondary/20 text-secondary rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all"
                        >
                            <CheckCircle2 size={16} /> {t('action_make_default')}
                        </button>

                        <button
                            onClick={() => toggleStatus(lang)}
                            disabled={lang.is_default}
                            className={`w-full h-12 bg-secondary text-white rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-secondary/20 ${lang.is_default ? 'opacity-50 cursor-not-allowed active:scale-100' : ''}`}
                        >
                            <Check size={16} /> {lang.is_active ? t('action_make_passive') : t('action_make_active')}
                        </button>

                        <button
                            className="w-full h-12 bg-white dark:bg-bg-dark border border-[#EA4335]/20 text-[#EA4335] rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all"
                        >
                            <Trash2 size={16} /> {t('action_delete')}
                        </button>
                    </div>
                ))}
            </div>

            {/* Add Language Modal */}
            {isAddModalOpen && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-primary/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setIsAddModalOpen(false)}
                    />

                    <div className="relative w-full max-w-md bg-white dark:bg-[#1A2530] rounded-2xl shadow-2xl overflow-hidden border border-gray-100 dark:border-gray-800 animate-in fade-in zoom-in duration-200">
                        <div className="p-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
                            <div className="flex items-center gap-2 text-primary dark:text-white">
                                <Globe className="text-secondary" size={18} />
                                <h3 className="text-sm font-black tracking-wider">{editingId ? t('modal_title_edit') : t('modal_title_add')}</h3>
                            </div>
                            <button
                                onClick={() => setIsAddModalOpen(false)}
                                className="p-1 hover:bg-gray-100 dark:hover:bg-white/5 rounded-md text-muted transition-colors"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        <form onSubmit={handleSaveLanguage} className="p-6 space-y-5">
                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('label_name')}</label>
                                    <input
                                        type="text"
                                        required
                                        value={formData.name}
                                        onChange={e => setFormData({ ...formData, name: e.target.value })}
                                        placeholder={t('placeholder_name')}
                                        className="w-full h-11 px-4 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('label_short_code')}</label>
                                    <input
                                        type="text"
                                        required
                                        value={formData.short_code}
                                        onChange={e => setFormData({ ...formData, short_code: e.target.value })}
                                        placeholder={t('placeholder_short_code')}
                                        className="w-full h-11 px-4 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('label_locale_code')}</label>
                                    <input
                                        type="text"
                                        value={formData.locale_code}
                                        onChange={e => setFormData({ ...formData, locale_code: e.target.value })}
                                        placeholder={t('placeholder_locale_code')}
                                        className="w-full h-11 px-4 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-black text-muted tracking-widest uppercase">{t('label_sort_order')}</label>
                                    <input
                                        type="number"
                                        value={formData.sort_order}
                                        onChange={e => setFormData({ ...formData, sort_order: parseInt(e.target.value) })}
                                        className="w-full h-11 px-4 bg-[#F8F9FA] dark:bg-white/5 border border-gray-200 dark:border-gray-800 rounded-xl text-sm font-bold focus:outline-none focus:border-secondary transition-colors"
                                    />
                                </div>
                            </div>

                            <div className="flex flex-col sm:flex-row gap-6 pt-2">
                                <label className="flex items-center gap-3 cursor-pointer group text-primary dark:text-gray-300">
                                    <div className="relative">
                                        <input
                                            type="checkbox"
                                            checked={formData.direction === 'rtl'}
                                            onChange={e => setFormData({ ...formData, direction: e.target.checked ? 'rtl' : 'ltr' })}
                                            className="sr-only peer"
                                        />
                                        <div className="w-10 h-5 bg-gray-200 dark:bg-white/10 rounded-full peer peer-checked:bg-secondary transition-colors" />
                                        <div className="absolute left-1 top-1 w-3 h-3 bg-white rounded-full peer-checked:translate-x-5 transition-transform" />
                                    </div>
                                    <span className="text-[10px] font-black text-muted uppercase tracking-widest group-hover:text-primary transition-colors">{t('label_direction_rtl')}</span>
                                </label>

                                <label className="flex items-center gap-3 cursor-pointer group text-primary dark:text-gray-300">
                                    <div className="relative">
                                        <input
                                            type="checkbox"
                                            checked={formData.is_active}
                                            onChange={e => setFormData({ ...formData, is_active: e.target.checked })}
                                            className="sr-only peer"
                                        />
                                        <div className="w-10 h-5 bg-gray-200 dark:bg-white/10 rounded-full peer peer-checked:bg-green-500 transition-colors" />
                                        <div className="absolute left-1 top-1 w-3 h-3 bg-white rounded-full peer-checked:translate-x-5 transition-transform" />
                                    </div>
                                    <span className="text-[10px] font-black text-muted uppercase tracking-widest group-hover:text-primary transition-colors">{t('label_active_status')}</span>
                                </label>
                            </div>

                            <div className="flex items-center gap-2 pt-4">
                                <button
                                    type="button"
                                    onClick={() => setIsAddModalOpen(false)}
                                    className="flex-1 h-12 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-xl text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-colors"
                                >
                                    {t('button_cancel')}
                                </button>
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="flex-1 h-12 bg-secondary text-white rounded-xl text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-secondary/20 active:scale-95 disabled:opacity-50"
                                >
                                    {saving ? <Loader2 className="animate-spin" size={16} /> : t('button_save')}
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Import Language Modal */}
            {isImportModalOpen && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-primary/40 backdrop-blur-sm transition-opacity"
                        onClick={() => setIsImportModalOpen(false)}
                    />

                    <div className="relative w-full max-w-md bg-white dark:bg-[#1A2530] rounded-2xl shadow-2xl overflow-hidden border border-gray-100 dark:border-gray-800 animate-in fade-in zoom-in duration-200">
                        <div className="p-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
                            <div className="flex items-center gap-2 text-primary dark:text-white">
                                <FileJson className="text-secondary" size={18} />
                                <h3 className="text-sm font-black tracking-wider">{t('modal_title_import')}</h3>
                            </div>
                            <button
                                onClick={() => setIsImportModalOpen(false)}
                                className="p-1 hover:bg-gray-100 dark:hover:bg-white/5 rounded-md text-muted transition-colors"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        <div className="p-6 space-y-6">
                            <div className="border-2 border-dashed border-gray-100 dark:border-gray-800 rounded-2xl p-8 flex flex-col items-center justify-center text-center space-y-4 hover:border-blue-500/30 transition-colors cursor-pointer group">
                                <div className="w-16 h-16 rounded-full bg-blue-50 dark:bg-blue-500/5 flex items-center justify-center text-blue-500 group-hover:scale-110 transition-transform">
                                    <Upload size={32} />
                                </div>
                                <div className="space-y-1">
                                    <p className="text-xs font-black text-primary dark:text-white tracking-wider">{t('import_select_json')}</p>
                                    <p className="text-[10px] text-muted font-bold tracking-tight">{t('import_drag_drop')}</p>
                                </div>
                            </div>

                            <div className="bg-blue-50/50 dark:bg-blue-500/5 p-4 rounded-xl border border-blue-100/50 dark:border-blue-500/10 flex gap-3">
                                <AlertCircle size={18} className="text-blue-500 shrink-0" />
                                <p className="text-[10px] font-bold text-blue-600/80 dark:text-blue-400/80 leading-relaxed">
                                    {t('import_warning')}
                                </p>
                            </div>

                            <div className="flex items-center gap-2">
                                <button
                                    onClick={() => setIsImportModalOpen(false)}
                                    className="flex-1 h-12 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-xl text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-colors"
                                >
                                    {t('button_cancel')}
                                </button>
                                <button className="flex-1 h-12 bg-primary text-white rounded-xl text-[10px] font-black tracking-widest hover:opacity-90 transition-all shadow-lg shadow-primary/20 active:scale-95">
                                    {t('button_upload')}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default LanguageSettingsPage;
