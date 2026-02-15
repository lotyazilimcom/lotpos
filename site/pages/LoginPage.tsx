
import React, { useState } from 'react';
import { supabase } from '../lib/supabaseClient';
import { useTranslation } from '@/hooks/useTranslation';

interface LoginPageProps {
  onLogin: () => void;
}

const LoginPage: React.FC<LoginPageProps> = ({ onLogin }) => {
  const { t } = useTranslation();
  const [username, setUsername] = useState('admin');
  const [password, setPassword] = useState('admin');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError(null);

    try {
      // Custom Auth: Query the admins table
      const { data: admin, error: supabaseError } = await supabase
        .from('admins')
        .select('*')
        .eq('username', username)
        .single();

      if (supabaseError || !admin) {
        setError(t('login_error_invalid_credentials'));
        setIsLoading(false);
        return;
      }

      // In a production app, we would use a hash comparison (e.g. bcrypt)
      // For this custom implementation as requested, we compare the password_hash field
      if (admin.password_hash === password) {
        onLogin();
      } else {
        setError(t('login_error_invalid_credentials'));
      }
    } catch (err) {
      console.error('Login error:', err);
      setError(t('login_error_generic'));
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-bg-light dark:bg-bg-dark transition-colors p-4">
      <div className="bg-paper-light dark:bg-paper-dark rounded-xl shadow-2xl p-8 w-full max-w-md border border-gray-100 dark:border-gray-800">
        <div className="text-center mb-10">
          <h1 className="text-3xl font-bold text-primary dark:text-white tracking-wider">
            {t('app_brand_primary')} <span className="text-secondary">{t('app_brand_secondary')}</span>
          </h1>
          <p className="text-sm text-muted mt-2 tracking-widest text-[10px] font-bold">{t('login_title')}</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6">
          {error && (
            <div className="bg-red-50 dark:bg-red-900/10 border border-red-200 dark:border-red-800 p-3 rounded-lg flex items-center gap-2">
              <span className="text-xs text-secondary font-bold">{error}</span>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-black text-primary dark:text-gray-300 tracking-widest ml-1">{t('login_label_username')}</label>
            <input
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full h-11 px-4 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary dark:focus:border-secondary transition-all text-sm text-primary dark:text-white font-bold"
              placeholder={t('login_placeholder_username')}
              required
            />
          </div>

          <div className="space-y-1.5">
            <div className="flex items-center justify-between px-1">
              <label className="text-xs font-black text-primary dark:text-gray-300 tracking-widest">{t('login_label_password')}</label>
              <a href="#" className="text-[10px] text-secondary font-bold hover:underline tracking-widest">{t('login_forgot_password')}</a>
            </div>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full h-11 px-4 bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg focus:outline-none focus:ring-2 focus:ring-primary/20 focus:border-primary dark:focus:border-secondary transition-all text-sm text-primary dark:text-white font-bold"
              placeholder={t('login_placeholder_password')}
              required
            />
          </div>

          <div className="flex items-center mt-2">
            <input type="checkbox" id="remember" className="w-4 h-4 rounded border-gray-300 text-secondary focus:ring-secondary cursor-pointer" />
            <label htmlFor="remember" className="ml-2 text-[10px] text-muted font-bold tracking-widest cursor-pointer select-none">{t('login_remember_me')}</label>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full h-12 bg-secondary hover:bg-secondary/90 text-white text-xs font-black tracking-[0.2em] rounded-xl shadow-lg shadow-secondary/20 transition-all transform active:scale-[0.98] disabled:opacity-50"
          >
            {isLoading ? t('login_button_signing_in') : t('login_button_sign_in')}
          </button>
        </form>

        <div className="mt-8 pt-6 border-t border-gray-100 dark:border-gray-800 text-center">
          <p className="text-[10px] font-bold text-muted tracking-widest">{t('login_no_account')} <a href="#" className="text-secondary font-black hover:underline">{t('login_contact_support')}</a></p>
        </div>
      </div>
    </div>
  );
};

export default LoginPage;
