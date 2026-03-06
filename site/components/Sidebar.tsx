
import React, { useState, useEffect } from 'react';
import { NavLink, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  Monitor,
  Settings,
  LogOut,
  X,
  Globe,
  ChevronDown
} from 'lucide-react';
import { useTranslation } from '@/hooks/useTranslation';

interface SidebarProps {
  isOpen?: boolean;
  onClose?: () => void;
}

const Sidebar: React.FC<SidebarProps> = ({ isOpen, onClose }) => {
  const { dir, t } = useTranslation();
  const location = useLocation();
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isLiteSettingsMenuOpen, setIsLiteSettingsMenuOpen] = useState(false);

  // Auto-expand if on a settings page
  useEffect(() => {
    if (location.pathname.includes('/settings/languages')) {
      setIsSettingsOpen(true);
    }
    if (location.pathname.includes('/settings/lite-version')) {
      setIsLiteSettingsMenuOpen(true);
    }
  }, [location.pathname]);

  const menuItems = [
    { labelKey: 'menu_dashboard', icon: <LayoutDashboard size={18} />, path: '/dashboard' },
    { labelKey: 'menu_customers', icon: <Users size={18} />, path: '/dashboard/customers' },
    { labelKey: 'menu_lite_users', icon: <Monitor size={18} />, path: '/dashboard/lite-users' },
  ];

  return (
    <aside className={`
      w-64 h-screen fixed inset-y-0 start-0 bg-primary text-white/80 flex flex-col z-20 shadow-xl transition-all duration-300
      ${isOpen
        ? 'translate-x-0'
        : (dir === 'rtl' ? 'translate-x-full lg:translate-x-0' : '-translate-x-full lg:translate-x-0')
      }
    `}>
      {/* Logo Section */}
      <div className="p-6 mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-wider">
            {t('app_brand_primary')} <span className="text-secondary">{t('app_brand_secondary')}</span>
          </h1>
          <p className="text-[10px] text-muted tracking-widest mt-1 opacity-70">{t('app_tagline')}</p>
        </div>
        <button
          onClick={onClose}
          className="lg:hidden p-2 text-white/60 hover:text-white transition-colors"
        >
          <X size={20} />
        </button>
      </div>

      {/* Navigation Menu */}
      <nav className="flex-1 px-3 space-y-1">
        {menuItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            end={item.path === '/dashboard'}
            className={({ isActive }) => `
              flex items-center gap-3 px-4 h-11 rounded-md transition-all duration-200 group
              ${isActive
                ? 'bg-white/5 text-secondary border-s-4 border-secondary font-medium'
                : 'hover:bg-white/10 hover:text-white'
              }
            `}
          >
            <span className="group-hover:scale-110 transition-transform">{item.icon}</span>
            <span className="text-sm">{t(item.labelKey)}</span>
          </NavLink>
        ))}

        {/* New Ayarlar Menu under Deneyenler */}
        <div>
          <button
            onClick={() => setIsLiteSettingsMenuOpen(!isLiteSettingsMenuOpen)}
            className={`
              w-full flex items-center justify-between px-4 h-11 rounded-md transition-all duration-200 group
              ${location.pathname.includes('/dashboard/settings/lite-version')
                ? 'text-white'
                : 'text-white/80 hover:bg-white/10 hover:text-white'
              }
            `}
          >
            <div className="flex items-center gap-3">
              <span className="group-hover:scale-110 transition-transform"><Settings size={18} /></span>
              <span className="text-sm">{t('menu_settings')}</span>
            </div>
            <ChevronDown
              size={16}
              className={`transition-transform duration-300 ${isLiteSettingsMenuOpen ? 'rotate-180' : ''}`}
            />
          </button>

          {/* Submenu Items for Lite Settings */}
          <div className={`overflow-hidden transition-all duration-300 ease-in-out ${isLiteSettingsMenuOpen ? 'max-h-20 opacity-100 mt-1' : 'max-h-0 opacity-0'}`}>
            <NavLink
              to="/dashboard/settings/lite-version"
              className={({ isActive }) => `
                flex items-center gap-3 ps-11 pe-4 h-10 rounded-md transition-all duration-200 group text-sm relative
                ${isActive
                  ? 'text-[#EA4335] font-medium bg-[#EA4335]/10'
                  : 'text-white/60 hover:text-white hover:bg-white/5'
                }
              `}
            >
              {({ isActive }) => (
                <>
                  {isActive && (
                    <span className="absolute start-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-[#EA4335] rounded-e-full" />
                  )}
                  <span className="group-hover:translate-x-1 transition-transform rtl:group-hover:-translate-x-1"><Settings size={16} /></span>
                  <span>{t('menu_lite_settings')}</span>
                </>
              )}
            </NavLink>
          </div>
        </div>

        {/* Settings Group Section */}
        <div className="h-4" />
        <div className="!mt-12 mb-2 px-4">
          <p className="text-[10px] font-black text-muted tracking-[0.2em]">{t('menu_site_settings')}</p>
          <div className="h-[1px] w-full bg-white/5 mt-2" />
        </div>

        <div className="px-2 space-y-1">
          {/* Collapsible Parent: Genel Ayarlar */}
          <div>
            <button
              onClick={() => setIsSettingsOpen(!isSettingsOpen)}
              className={`
                w-full flex items-center justify-between px-4 h-11 rounded-md transition-all duration-200 group
                ${location.pathname.includes('/dashboard/settings/languages')
                  ? 'text-white'
                  : 'text-white/80 hover:bg-white/10 hover:text-white'
                }
              `}
            >
              <div className="flex items-center gap-3">
                <span className="group-hover:scale-110 transition-transform"><Settings size={18} /></span>
                <span className="text-sm">{t('menu_general_settings')}</span>
              </div>
              <ChevronDown
                size={16}
                className={`transition-transform duration-300 ${isSettingsOpen ? 'rotate-180' : ''}`}
              />
            </button>

            {/* Submenu Items for General Settings */}
            <div className={`overflow-hidden transition-all duration-300 ease-in-out ${isSettingsOpen ? 'max-h-20 opacity-100 mt-1' : 'max-h-0 opacity-0'}`}>
              <NavLink
                to="/dashboard/settings/languages"
                className={({ isActive }) => `
                  flex items-center gap-3 ps-11 pe-4 h-10 rounded-md transition-all duration-200 group text-sm relative
                  ${isActive
                    ? 'text-[#EA4335] font-medium bg-[#EA4335]/10'
                    : 'text-white/60 hover:text-white hover:bg-white/5'
                  }
                `}
              >
                {/* Active Indicator Dot */}
                {({ isActive }) => (
                  <>
                    {isActive && (
                      <span className="absolute start-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-[#EA4335] rounded-e-full" />
                    )}
                    <span className="group-hover:translate-x-1 transition-transform rtl:group-hover:-translate-x-1"><Globe size={16} /></span>
                    <span>{t('menu_language_settings')}</span>
                  </>
                )}
              </NavLink>
            </div>
          </div>
        </div>
      </nav>

      {/* Bottom Profile/Action */}
      <div className="p-4 border-t border-white/5">
        <button className="flex items-center gap-3 px-4 h-11 w-full text-white/60 hover:text-white hover:bg-white/10 rounded-md transition-all">
          <LogOut size={18} />
          <span className="text-sm">{t('action_logout')}</span>
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
