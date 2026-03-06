
import React, { useState, useEffect } from 'react';
import { HashRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import LoginPage from '@/pages/LoginPage';
import DashboardPage from '@/pages/DashboardPage';
import CustomersPage from '@/pages/CustomersPage';
import LiteUsersPage from '@/pages/LiteUsersPage';
import CustomerDetailPage from '@/pages/CustomerDetailPage';
import CustomerEditPage from '@/pages/CustomerEditPage';
import LanguageSettingsPage from '@/pages/LanguageSettingsPage';
import LiteSettingsPage from '@/pages/LiteSettingsPage';
import MainLayout from '@/components/MainLayout';
import { LanguageProvider } from '@/context/LanguageContext';

const App: React.FC = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(false);

  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDarkMode]);

  const handleLogin = () => {
    setIsAuthenticated(true);
  };

  const toggleDarkMode = () => {
    setIsDarkMode(!isDarkMode);
  };

  return (
    <LanguageProvider>
      <Router>
        <Routes>
          <Route
            path="/login"
            element={
              isAuthenticated ?
                <Navigate to="/dashboard" /> :
                <LoginPage onLogin={handleLogin} />
            }
          />
          <Route
            path="/dashboard/*"
            element={
              isAuthenticated ? (
                <MainLayout
                  isDarkMode={isDarkMode}
                  toggleDarkMode={toggleDarkMode}
                >
                  <Routes>
                    <Route index element={<DashboardPage />} />
                    <Route path="customers" element={<CustomersPage />} />
                    <Route path="customers/new" element={<CustomerEditPage />} />
                    <Route path="customers/:id" element={<CustomerDetailPage />} />
                    <Route path="customers/:id/edit" element={<CustomerEditPage />} />
                    <Route path="lite-users" element={<LiteUsersPage />} />
                    <Route path="accounts" element={<div className="p-6">Cari Hesaplar Sayfası</div>} />
                    <Route path="invoices" element={<div className="p-6">Faturalar Sayfası</div>} />
                    <Route path="reports" element={<div className="p-6">Raporlar Sayfası</div>} />
                    <Route path="settings" element={<div className="p-6">Ayarlar Sayfası</div>} />
                    <Route path="settings/languages" element={<LanguageSettingsPage />} />
                    <Route path="settings/lite-version" element={<LiteSettingsPage />} />
                  </Routes>
                </MainLayout>
              ) : (
                <Navigate to="/login" />
              )
            }
          />
          <Route path="/" element={<Navigate to={isAuthenticated ? "/dashboard" : "/login"} />} />
        </Routes>
      </Router>
    </LanguageProvider>
  );
};

export default App;
