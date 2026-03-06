
import React, { useState, useEffect, useRef } from 'react';
import { Search, Bell, Moon, Sun, User, Lock, Menu, Globe, Check } from 'lucide-react';
import { useLocation } from 'react-router-dom';
import LicensingModal from './LicensingModal';
import { useTranslation } from '@/hooks/useTranslation';
import { supabase } from '@/lib/supabaseClient';

interface HeaderProps {
  isDarkMode: boolean;
  toggleDarkMode: () => void;
  onMenuClick?: () => void;
}

const Header: React.FC<HeaderProps> = ({ isDarkMode, toggleDarkMode, onMenuClick }) => {
  const location = useLocation();
  const [isLicenseModalOpen, setLicenseModalOpen] = useState(false);
  const { currentLang, setLanguage, t } = useTranslation();

  // Language Selector State
  const [isLangMenuOpen, setIsLangMenuOpen] = useState(false);
  const [activeLanguages, setActiveLanguages] = useState<any[]>([]);
  const langMenuRef = useRef<HTMLDivElement>(null);

  // Fetch active languages for dropdown
  useEffect(() => {
    const fetchLanguages = async () => {
      const { data } = await supabase
        .from('languages')
        .select('short_code, name, locale_code')
        .eq('is_active', true)
        .order('sort_order', { ascending: true });

      if (data) setActiveLanguages(data);
    };
    fetchLanguages();
  }, []);

  // Click outside listener for language menu
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (langMenuRef.current && !langMenuRef.current.contains(event.target as Node)) {
        setIsLangMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const getPageTitle = () => {
    const path = location.pathname;
    if (path === '/dashboard') return t('menu_dashboard');
    if (path.includes('customers')) return t('menu_customers');
    if (path.includes('accounts')) return t('menu_accounts');
    if (path.includes('invoices')) return t('menu_invoices');
    if (path.includes('reports')) return t('menu_reports');
    if (path.includes('settings')) return t('menu_settings');
    return t('menu_panel');
  };

  return (
    <header className="sticky top-0 z-10 h-16 bg-paper-light/80 dark:bg-paper-dark/80 backdrop-blur-md shadow-sm flex items-center justify-between px-4 md:px-6 border-b border-gray-200 dark:border-gray-800 transition-colors">
      <div className="flex items-center gap-2 md:gap-4">
        <button
          onClick={onMenuClick}
          className="lg:hidden p-2 text-muted hover:text-primary dark:hover:text-white transition-colors"
        >
          <Menu size={20} />
        </button>
        <h2 className="text-base md:text-lg font-semibold text-primary dark:text-white truncate max-w-[120px] sm:max-w-none">{getPageTitle()}</h2>
      </div>

      <div className="flex items-center gap-4">
        {/* Compact Search */}
        <div className="hidden md:flex items-center bg-gray-100 dark:bg-gray-800 rounded-md px-3 h-9 border border-transparent focus-within:border-primary/20 dark:focus-within:border-white/20 transition-all">
          <Search size={16} className="text-muted" />
          <input
            type="text"
            placeholder={t('header_search_placeholder')}
            className="bg-transparent border-none focus:ring-0 text-sm ml-2 w-32 lg:w-48 text-primary dark:text-gray-200 outline-none"
          />
        </div>

        {/* Language Selector */}
        <div className="relative" ref={langMenuRef}>
          <button
            onClick={() => setIsLangMenuOpen(!isLangMenuOpen)}
            className={`flex items-center gap-2 p-2 rounded-lg transition-all ${isLangMenuOpen ? 'bg-gray-100 dark:bg-white/10 text-primary dark:text-white' : 'text-muted hover:text-primary dark:hover:text-white'}`}
          >
            <div className="w-5 h-5 rounded-full overflow-hidden flex items-center justify-center bg-gray-200 dark:bg-gray-700 text-[10px] font-black uppercase text-secondary">
              {currentLang}
            </div>
            <Globe size={18} className={isLangMenuOpen ? 'text-primary dark:text-white' : ''} />
          </button>

          {isLangMenuOpen && (
            <div className="absolute right-0 top-full mt-2 w-48 bg-white dark:bg-[#1A2530] rounded-xl shadow-xl border border-gray-100 dark:border-gray-800 py-2 animate-in fade-in slide-in-from-top-2 z-50">
              <div className="px-3 py-2 border-b border-gray-100 dark:border-gray-800 mb-1">
                <p className="text-[10px] font-black text-muted tracking-[0.2em] uppercase">{t('header_language_selection')}</p>
              </div>
              {activeLanguages.map((lang) => (
                <button
                  key={lang.short_code}
                  onClick={() => {
                    setLanguage(lang.short_code);
                    setIsLangMenuOpen(false);
                  }}
                  className={`w-full px-4 py-2.5 flex items-center justify-between text-[11px] font-bold tracking-wide transition-colors ${currentLang === lang.short_code
                    ? 'bg-[#EA4335]/10 text-[#EA4335]'
                    : 'text-primary dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-white/5'
                    }`}
                >
                  <span className="uppercase">{lang.name}</span>
                  {currentLang === lang.short_code && <Check size={14} />}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Notifications */}
        <button className="relative p-2 text-muted hover:text-primary dark:hover:text-white transition-colors">
          <Bell size={20} />
          <span className="absolute top-1 right-1 w-2 h-2 bg-secondary rounded-full border-2 border-white dark:border-paper-dark"></span>
        </button>

        {/* Theme Toggle */}
        <button
          onClick={toggleDarkMode}
          className="p-2 text-muted hover:text-primary dark:hover:text-white transition-colors"
        >
          {isDarkMode ? <Sun size={20} /> : <Moon size={20} />}
        </button>

        {/* User Avatar */}
        <div className="flex items-center gap-3 pl-4 border-l border-gray-200 dark:border-gray-800">
          <div className="hidden lg:block text-right">
            <p className="text-xs font-semibold text-primary dark:text-white">{t('header_user_name')}</p>
            <p className="text-[10px] text-muted">{t('header_user_role_admin')}</p>
          </div>
          <div className="w-9 h-9 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center text-primary dark:text-gray-300">
            <User size={18} />
          </div>
        </div>
      </div>

      <LicensingModal
        isOpen={isLicenseModalOpen}
        onClose={() => setLicenseModalOpen(false)}
      />
    </header>
  );
};

export default Header;
