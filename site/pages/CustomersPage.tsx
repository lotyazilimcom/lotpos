
import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Search,
  Filter,
  Download,
  Plus,
  MapPin,
  Phone,
  MoreVertical,
  Eye,
  Edit2,
  Trash2,
  Loader2
} from 'lucide-react';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

interface Customer {
  id: string;
  company_name: string;
  contact_name: string;
  phone: string;
  email: string;
  city: string;
  status: 'active' | 'passive';
  created_at: string;
  // Joined from licenses
  licenses?: {
    package_name: string;
    type: 'Aylık' | 'Yıllık';
    end_date: string;
    modules: string[];
  }[];
}

const CustomersPage: React.FC = () => {
  const navigate = useNavigate();
  const { t, currentLang } = useTranslation();
  const locale = currentLang === 'ar' ? 'ar-SA' : currentLang === 'en' ? 'en-US' : 'tr-TR';
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [pageSize, setPageSize] = useState<number>(25);
  const [openMenuId, setOpenMenuId] = useState<string | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    fetchCustomers();
  }, []);

  const fetchCustomers = async () => {
    setLoading(true);
    try {
      // Time-based automation: expire licenses -> passive + grace (DB-side)
      const { error: sweepError } = await supabase.rpc('lot_sweep_expired_licenses');
      if (sweepError) console.warn('lot_sweep_expired_licenses error:', sweepError);

      const { data, error } = await supabase
        .from('customers')
        .select(`
          *,
          licenses (*)
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setCustomers(data || []);
    } catch (err) {
      console.error('Error fetching customers:', err);
    } finally {
      setLoading(false);
    }
  };

  // Filtered customers
  const filteredCustomers = customers.filter(c =>
    c.company_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.contact_name.toLowerCase().includes(searchTerm.toLowerCase())
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

  const getActiveLicense = (customer: Customer) => {
    if (!customer.licenses || customer.licenses.length === 0) return null;
    return [...customer.licenses].sort((a, b) => {
      const aTime = new Date(a.end_date).getTime();
      const bTime = new Date(b.end_date).getTime();
      return (Number.isFinite(bTime) ? bTime : 0) - (Number.isFinite(aTime) ? aTime : 0);
    })[0];
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
              placeholder={t('customers_search_placeholder')}
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full h-10 pl-10 pr-4 bg-[#F8F9FA] dark:bg-[#1A2530] border border-gray-200 dark:border-gray-800 rounded-md text-sm focus:outline-none focus:border-[#2C3E50]/20 transition-all font-bold"
            />
          </div>
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <button className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-md text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-all shadow-sm">
            <Filter size={14} /> {t('action_filter')}
          </button>
          <button className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-4 h-10 bg-white dark:bg-bg-dark border border-gray-200 dark:border-gray-800 rounded-md text-[10px] font-black tracking-widest text-muted hover:text-primary dark:hover:text-white transition-all shadow-sm">
            <Download size={14} /> {t('action_export')}
          </button>
          <button
            onClick={() => navigate('/dashboard/customers/new')}
            className="flex-1 sm:flex-none flex items-center justify-center gap-2 px-6 h-10 bg-secondary text-white rounded-md text-[10px] font-black tracking-[0.15em] hover:opacity-90 transition-all shadow-md shadow-secondary/10 active:scale-95"
          >
            <Plus size={16} /> {t('customers_new_customer')}
          </button>
        </div>
      </div>

      {/* Desktop Table Section */}
      <div className="hidden md:block bg-white dark:bg-[#1A2530] rounded-xl shadow-sm border border-gray-100 dark:border-gray-800">
        <div className="overflow-x-visible">
          <table className="w-full text-left table-fixed">
            <thead>
              <tr className="border-b border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02]">
                <th className="w-[200px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em]">{t('customers_table_customer_company')}</th>
                <th className="w-[80px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_type')}</th>
                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_city')}</th>
                <th className="w-[120px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_phone')}</th>
                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_start')}</th>
                <th className="w-[100px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_end')}</th>
                <th className="min-w-[150px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em]">{t('customers_table_license_content')}</th>
                <th className="w-[90px] px-2 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-center">{t('customers_table_status')}</th>
                <th className="w-[90px] px-6 py-4 text-[10px] font-black text-primary dark:text-muted tracking-[0.15em] text-right">{t('customers_table_actions')}</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
              {filteredCustomers.map((customer) => {
                const license = getActiveLicense(customer);
                return (
                  <tr key={customer.id} className="hover:bg-secondary/[0.02] dark:hover:bg-white/[0.02] transition-colors group text-primary dark:text-gray-300">
                    <td className="px-6 py-5">
                      <div className="truncate">
                        <p className="text-sm font-black truncate">{customer.contact_name}</p>
                        <p className="text-[11px] text-[#95A5A6] font-bold truncate tracking-tight">{customer.company_name}</p>
                      </div>
                    </td>
                    <td className="px-2 py-5 text-center">
                      <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-black tracking-wide border ${license?.type === 'Yıllık'
                        ? 'bg-blue-50 text-blue-600 border-blue-100 dark:bg-blue-500/10 dark:text-blue-400 dark:border-blue-500/20'
                        : 'bg-amber-50 text-amber-600 border-amber-100 dark:bg-amber-500/10 dark:text-amber-400 dark:border-amber-500/20'
                        }`}>
                        {license?.type || '-'}
                      </span>
                    </td>
                    <td className="px-2 py-5 text-center text-[11px] font-black uppercase tracking-wider">
                      {customer.city}
                    </td>
                    <td className="px-2 py-5 text-center text-[11px] font-bold whitespace-nowrap">
                      {customer.phone}
                    </td>
                    <td className="px-2 py-5 text-center text-[10px] font-black tracking-tighter">
                      {new Date(customer.created_at).toLocaleDateString(locale)}
                    </td>
                    <td className="px-2 py-5 text-center text-[10px] font-black tracking-tighter text-secondary">
                      {license ? new Date(license.end_date).toLocaleDateString(locale) : '-'}
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex flex-wrap gap-1">
                        {license?.modules?.map((mod, idx) => (
                          <span key={idx} className="px-1.5 py-0.5 bg-bg-light dark:bg-white/5 border border-gray-200 dark:border-gray-700 rounded text-[8px] font-black tracking-widest text-primary dark:text-gray-400">
                            {mod}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="px-2 py-5 text-center">
                      <span className={`inline-flex items-center gap-1 text-[10px] font-black tracking-widest ${customer.status === 'active' ? 'text-green-500' : 'text-red-400'
                        }`}>
                        <span className={`w-1.5 h-1.5 rounded-full ${customer.status === 'active' ? 'bg-green-500' : 'bg-red-400'}`} />
                        {customer.status === 'active' ? t('status_active') : t('status_passive')}
                      </span>
                    </td>
                    <td className="px-6 py-5 text-right">
                      <div className="relative inline-block">
                        <button
                          onClick={() => setOpenMenuId(openMenuId === customer.id ? null : customer.id)}
                          className="p-2 text-muted hover:text-primary dark:hover:text-white transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-white/5"
                        >
                          <MoreVertical size={16} />
                        </button>

                        {openMenuId === customer.id && (
                          <div
                            ref={dropdownRef}
                            className={`absolute right-0 w-32 bg-white dark:bg-[#1A2530] border border-gray-100 dark:border-gray-800 rounded-lg shadow-xl z-[9999] animate-in fade-in duration-200 ${
                              // Smart Positioning: Open upward if it's the last row
                              filteredCustomers.length > 2 && filteredCustomers.findIndex(c => c.id === customer.id) === filteredCustomers.length - 1
                                ? 'bottom-full mb-1 slide-in-from-bottom-2'
                                : 'top-full mt-1 slide-in-from-top-2'
                              }`}
                          >
                            <button
                              onClick={() => { navigate(`/dashboard/customers/${customer.id}`); setOpenMenuId(null); }}
                              className="flex items-center gap-2 w-full px-4 py-2.5 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors"
                            >
                              <Eye size={12} className="text-secondary" /> {t('action_detail')}
                            </button>
                            <button
                              onClick={() => { navigate(`/dashboard/customers/${customer.id}/edit`); setOpenMenuId(null); }}
                              className="flex items-center gap-2 w-full px-4 py-2.5 text-[10px] font-black tracking-widest text-primary dark:text-gray-300 hover:bg-bg-light dark:hover:bg-white/5 transition-colors border-t border-gray-50 dark:border-gray-800/50"
                            >
                              <Edit2 size={12} className="text-blue-500" /> {t('action_edit')}
                            </button>
                            <button
                              onClick={() => { /* Delete logic */ setOpenMenuId(null); }}
                              className="flex items-center gap-2 w-full px-4 py-2.5 text-[10px] font-black tracking-widest text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors border-t border-gray-50 dark:border-gray-800/50"
                            >
                              <Trash2 size={12} /> {t('action_delete')}
                            </button>
                          </div>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        <div className="px-6 py-3 border-t border-gray-100 dark:border-gray-800 bg-[#F8F9FA] dark:bg-white/[0.02] flex items-center justify-between">
          <p className="text-[10px] text-muted font-black tracking-widest">{t('customers_total_prefix')} {filteredCustomers.length} {t('customers_total_suffix')}</p>
          <div className="flex gap-1">
            <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_previous')}</button>
            <button className="px-3 py-1 text-[10px] font-black rounded bg-primary text-white transition-all">1</button>
            <button className="px-3 py-1 text-[10px] font-black rounded border border-gray-200 dark:border-gray-800 text-muted hover:bg-white dark:hover:bg-white/5 transition-all">{t('button_next')}</button>
          </div>
        </div>
      </div>

      {/* Mobile Card List Section */}
      <div className="block md:hidden space-y-4">
        {filteredCustomers.map((customer) => {
          const license = getActiveLicense(customer);
          return (
            <div key={customer.id} className="bg-white dark:bg-[#1A2530] rounded-2xl p-6 border border-gray-100 dark:border-gray-800 shadow-sm space-y-5">
              <div className="flex items-start justify-between">
                <div className="space-y-1">
                  <h3 className="text-base font-black text-primary dark:text-white leading-tight">{customer.contact_name}</h3>
                  <p className="text-[11px] text-muted font-bold uppercase tracking-tight">{customer.company_name}</p>
                </div>
                <span className={`inline-flex items-center gap-1 text-[10px] font-black tracking-widest ${customer.status === 'active' ? 'text-green-500' : 'text-red-400'}`}>
                  <span className={`w-1.5 h-1.5 rounded-full ${customer.status === 'active' ? 'bg-green-500' : 'bg-red-400'}`} />
                  {customer.status === 'active' ? t('status_active') : t('status_passive')}
                </span>
              </div>

              <div className="grid grid-cols-2 gap-4 pb-2">
                <div className="space-y-2">
                  <p className="text-[9px] font-black text-muted tracking-widest uppercase opacity-40">{t('customers_mobile_city_phone')}</p>
                  <div className="flex flex-col gap-1.5">
                    <span className="text-[11px] font-black text-primary dark:text-gray-300 flex items-center gap-2 uppercase">
                      <MapPin size={12} className="text-muted" /> {customer.city}
                    </span>
                    <span className="text-[11px] font-black text-primary dark:text-gray-300 flex items-center gap-2">
                      <Phone size={12} className="text-muted" /> {customer.phone}
                    </span>
                  </div>
                </div>
                <div className="space-y-2">
                  <p className="text-[9px] font-black text-muted tracking-widest uppercase opacity-40">{t('customers_mobile_license_end')}</p>
                  <div className="space-y-2">
                    <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-black tracking-wide border ${license?.type === 'Yıllık'
                      ? 'bg-blue-50 text-blue-600 border-blue-100 dark:bg-blue-500/10 dark:text-blue-400 dark:border-blue-500/20'
                      : 'bg-amber-50 text-amber-600 border-amber-100 dark:bg-amber-500/10 dark:text-amber-400 dark:border-amber-500/20'
                      }`}>
                      {license?.type || '-'}
                    </span>
                    <p className="text-[11px] font-black text-secondary tracking-tighter">
                      {license ? new Date(license.end_date).toLocaleDateString(locale) : '-'}
                    </p>
                  </div>
                </div>
              </div>

              <button
                onClick={() => navigate(`/dashboard/customers/${customer.id}`)}
                className="w-full h-12 bg-secondary text-white rounded-xl text-[10px] font-black tracking-[0.2em] flex items-center justify-center gap-2 active:scale-95 transition-all shadow-lg shadow-secondary/20"
              >
                <Eye size={16} /> {t('customers_view_details')}
              </button>
            </div>
          );
        })}

        {/* Mobile Pagination Placeholder */}
        <div className="flex items-center justify-center pt-2">
          <button className="text-[10px] font-black text-muted tracking-widest hover:text-primary transition-colors">{t('button_load_more')}</button>
        </div>
      </div>
    </div>
  );
};

export default CustomersPage;
