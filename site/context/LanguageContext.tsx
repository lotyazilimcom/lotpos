import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { supabase } from '@/lib/supabaseClient';
import tr from '../utils/i18n/tr';
import en from '../utils/i18n/en';
import ar from '../utils/i18n/ar';
import { LanguageDefinition } from '../utils/i18n/types';

const languageMap: Record<string, LanguageDefinition> = {
    tr, en, ar
};

interface LanguageContextType {
    currentLang: string;
    setLanguage: (lang: string) => void;
    t: (key: string) => string;
    loading: boolean;
    dir: 'ltr' | 'rtl';
}

const LanguageContext = createContext<LanguageContextType | undefined>(undefined);

export const LanguageProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
    const [currentLang, setCurrentLang] = useState<string>('tr');
    const [loading, setLoading] = useState(true);
    const [translations, setTranslations] = useState<Record<string, string>>({});

    // Initial Load & Caching Logic
    useEffect(() => {
        const initLanguage = async () => {
            try {
                // 1. Check LocalStorage (Priority #1)
                const cachedLang = localStorage.getItem('app_lang');
                if (cachedLang && languageMap[cachedLang]) {
                    setCurrentLang(cachedLang);
                    setLoading(false);
                    return;
                }

                // 2. Check Supabase Default (Priority #2)
                const { data } = await supabase
                    .from('languages')
                    .select('short_code')
                    .eq('is_default', true)
                    .single();

                if (data && data.short_code && languageMap[data.short_code]) {
                    setCurrentLang(data.short_code);
                    localStorage.setItem('app_lang', data.short_code); // Save for next time
                }
            } catch (error) {
                console.error('Failed to init language', error);
            } finally {
                setLoading(false);
            }
        };

        initLanguage();
    }, []);

    // Update Translations when Language Changes
    useEffect(() => {
        const langDef = languageMap[currentLang] || tr;
        const transMap: Record<string, string> = {};

        langDef.translations.forEach(item => {
            transMap[item.label] = item.translation;
        });

        setTranslations(transMap);

        // Update Document Direction (RTL/LTR)
        document.documentElement.dir = langDef.language.text_direction;
        document.documentElement.lang = langDef.language.language_code;

    }, [currentLang]);

    const handleSetLanguage = (lang: string) => {
        if (languageMap[lang]) {
            setCurrentLang(lang);
            localStorage.setItem('app_lang', lang); // Cache immediately
        }
    };

    const t = (key: string): string => {
        return translations[key] || key;
    };

    const value = {
        currentLang,
        setLanguage: handleSetLanguage,
        t,
        loading,
        dir: languageMap[currentLang]?.language.text_direction || 'ltr'
    };

    return (
        <LanguageContext.Provider value={value}>
            {children}
        </LanguageContext.Provider>
    );
};

export const useLanguage = () => {
    const context = useContext(LanguageContext);
    if (context === undefined) {
        throw new Error('useLanguage must be used within a LanguageProvider');
    }
    return context;
};
