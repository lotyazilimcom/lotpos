
import React, { useState } from 'react';
import { X, Copy, CheckCircle2, AlertCircle, Loader2, ShieldCheck } from 'lucide-react';
import { useTranslation } from '@/hooks/useTranslation';

interface LicensingModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const LicensingModal: React.FC<LicensingModalProps> = ({ isOpen, onClose }) => {
  const { t } = useTranslation();
  const [step, setStep] = useState<'id' | 'verify'>('id');
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState<'idle' | 'success' | 'error'>('idle');
  const licenseID = "X7B92";

  if (!isOpen) return null;

  const handleCopy = () => {
    navigator.clipboard.writeText(licenseID);
    // Simple alert-less UX would be better, but keeping it minimal
  };

  const handleVerify = () => {
    setLoading(true);
    setStatus('idle');
    setTimeout(() => {
      setLoading(false);
      // Mock result: succeed for demo
      setStatus('success');
    }, 2000);
  };

  const resetAndClose = () => {
    onClose();
    setTimeout(() => {
      setStep('id');
      setStatus('idle');
    }, 300);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-primary/40 backdrop-blur-sm transition-opacity"
        onClick={resetAndClose}
      />

      {/* Modal Content */}
      <div className="relative bg-paper-light dark:bg-paper-dark w-full max-w-md rounded-xl shadow-2xl overflow-hidden border border-gray-100 dark:border-gray-800 animate-in fade-in zoom-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-gray-100 dark:border-gray-800 flex items-center justify-between">
          <div className="flex items-center gap-2 text-primary dark:text-white">
            <ShieldCheck className="text-secondary" size={20} />
            <h3 className="font-semibold text-sm tracking-wider">{t('licensing_title')}</h3>
          </div>
          <button onClick={resetAndClose} className="p-1 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-md text-muted transition-colors">
            <X size={18} />
          </button>
        </div>

        {/* Body */}
        <div className="p-8 text-center">
          {step === 'id' ? (
            <div className="space-y-6">
              <div className="space-y-2">
                <p className="text-xs text-muted font-bold tracking-widest">{t('licensing_device_id_label')}</p>
                <div className="relative group">
                  <div className="bg-gray-50 dark:bg-white/5 p-6 rounded-lg border-2 border-dashed border-gray-200 dark:border-gray-700 flex items-center justify-center gap-4">
                    <span className="text-4xl font-mono font-bold tracking-[0.5em] text-primary dark:text-white pl-4">
                      {licenseID}
                    </span>
                    <button
                      onClick={handleCopy}
                      className="p-2 text-muted hover:text-secondary hover:bg-secondary/10 rounded-md transition-all"
                      title={t('action_copy')}
                    >
                      <Copy size={18} />
                    </button>
                  </div>
                </div>
              </div>

              <p className="text-sm text-muted px-4 leading-relaxed">
                {t('licensing_instruction')}
              </p>

              <button
                onClick={() => setStep('verify')}
                className="w-full h-11 bg-primary dark:bg-white dark:text-primary text-white text-sm font-bold rounded-md hover:opacity-90 transition-all"
              >
                {t('licensing_have_key_verify')}
              </button>
            </div>
          ) : (
            <div className="space-y-6">
              {status === 'success' ? (
                <div className="flex flex-col items-center gap-3 animate-in fade-in slide-in-from-bottom-2">
                  <CheckCircle2 size={64} className="text-green-500" />
                  <h4 className="text-lg font-bold text-primary dark:text-white">{t('licensing_activation_success')}</h4>
                  <p className="text-sm text-muted">{t('licensing_activation_success_message')}</p>
                  <button
                    onClick={resetAndClose}
                    className="mt-4 px-8 py-2 bg-primary text-white rounded-md text-sm font-medium"
                  >
                    {t('button_ok')}
                  </button>
                </div>
              ) : status === 'error' ? (
                <div className="flex flex-col items-center gap-3">
                  <AlertCircle size={64} className="text-red-500" />
                  <h4 className="text-lg font-bold text-primary dark:text-white">{t('licensing_error_title')}</h4>
                  <p className="text-sm text-muted">{t('licensing_error_message')}</p>
                  <button
                    onClick={() => setStatus('idle')}
                    className="mt-4 px-8 py-2 bg-gray-200 dark:bg-gray-800 text-primary dark:text-white rounded-md text-sm font-medium"
                  >
                    {t('button_retry')}
                  </button>
                </div>
              ) : (
                <div className="space-y-6">
                  <div className="space-y-2">
                    <p className="text-xs text-muted font-bold tracking-widest text-left">{t('licensing_license_key_label')}</p>
                    <input
                      type="text"
                      placeholder={t('common_masked_license_key')}
                      className="w-full h-12 bg-gray-50 dark:bg-white/5 border border-gray-200 dark:border-gray-700 rounded-lg px-4 text-center font-mono tracking-wider focus:outline-none focus:ring-2 focus:ring-secondary/50"
                    />
                  </div>

                  <button
                    disabled={loading}
                    onClick={handleVerify}
                    className="w-full h-11 bg-secondary text-white text-sm font-bold rounded-md hover:bg-secondary/90 transition-all flex items-center justify-center gap-2"
                  >
                    {loading ? (
                      <>
                        <Loader2 className="animate-spin" size={18} />
                        {t('licensing_button_verifying')}
                      </>
                    ) : (
                      t('licensing_button_verify_start')
                    )}
                  </button>
                  <button
                    onClick={() => setStep('id')}
                    className="text-xs text-muted hover:text-primary dark:hover:text-white transition-colors"
                  >
                    {t('button_return')}
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default LicensingModal;
